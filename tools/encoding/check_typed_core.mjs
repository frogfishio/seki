// Experimental typed-core and resource reconstruction. Not an admission checker.
import { AdmissionError } from "./decode_scb0.mjs";

const fail = (reason, path) => { throw new AdmissionError(reason, path); };
const same = (left, right) => JSON.stringify(left) === JSON.stringify(right);
const identityKey = (identity) => `${identity[0].join("::")}@${identity[1]}`;
const digestKey = (module) => module.digest.toString("hex");
const declKey = (module, index) => `${identityKey(module.identity)}#${digestKey(module)}:t${index}`;
const domainKey = (module, index) => `${identityKey(module.identity)}#${digestKey(module)}:d${index}`;
const callableKey = (module, index) =>
  `${identityKey(module.identity)}#${digestKey(module)}:f${index}`;

const choiceBits = (count) => count <= 1 ? 0 : Math.ceil(Math.log2(count));
const counterBits = (capacity) => choiceBits(capacity + 1);
const tagBits = (tag) => tag === 0 ? 0 : Math.floor(Math.log2(tag)) + 1;

export class TypedCoreChecker {
  constructor(decoded) {
    this.modules = decoded.modules ?? [decoded];
    this.byIdentity = new Map(this.modules.map((module) =>
      [identityKey(module.identity), module]));
    this.declarations = new Map();
    for (const module of this.modules) {
      module.types.forEach(([, declaration], index) =>
        this.declarations.set(declKey(module, index), { module, index, declaration }));
    }
    this.callableBounds = new Map();
  }

  importedModule(module, importIndex, path) {
    const entry = module.imports[importIndex];
    if (!entry) fail("0406", path);
    const target = this.byIdentity.get(identityKey(entry[0]));
    if (!target) fail("0401", path);
    return target;
  }

  resolveReference(module, reference, kind, path) {
    const target = reference[0] === 0
      ? module : this.importedModule(module, reference[1], path);
    const index = reference[0] === 0 ? reference[1] : reference[2];
    const entries = target[kind];
    if (!entries || index >= entries.length) fail("0700", path);
    return { module: target, index, value: entries[index] };
  }

  normalize(type, module, path = "type", expanding = new Set()) {
    const tag = type[0];
    if (tag <= 10) return [tag];
    if (tag === 11) return [tag, type[1]];
    if (tag === 12) {
      const ref = this.resolveReference(module, type[1], "domains", `${path}/domain`);
      return [tag, domainKey(ref.module, ref.index), type[2]];
    }
    if (tag === 13 || tag === 14) return [...type];
    if (tag === 15 || tag === 18 || tag === 19) {
      return [tag, this.normalize(type[1], module, `${path}/item`, expanding), ...type.slice(2)];
    }
    if (tag === 16 || tag === 20) return [tag,
      this.normalize(type[1], module, `${path}/left`, expanding),
      this.normalize(type[2], module, `${path}/right`, expanding)];
    if (tag === 17) return [tag, type[1].map((item, index) =>
      this.normalize(item, module, `${path}/items/${index}`, expanding))];
    if (tag === 21) {
      const owner = this.resolveReference(module, type[1][0], "types", `${path}/case`);
      return [tag, declKey(owner.module, owner.index), type[1][1]];
    }
    if (tag === 22) {
      const ref = this.resolveReference(module, type[1], "types", `${path}/reference`);
      const key = declKey(ref.module, ref.index);
      if (ref.value[1].tag !== 0) return [tag, key];
      if (expanding.has(key)) fail("0602", path);
      const next = new Set(expanding); next.add(key);
      return this.normalize(ref.value[1].body, ref.module, path, next);
    }
    fail("0100", path);
  }

  width(type, path = "type") {
    const tag = type[0];
    if (tag === 0) return 0;
    if (tag === 1) return 1;
    if (tag >= 2 && tag <= 9) return [8, 16, 32, 64, 8, 16, 32, 64][tag - 2];
    if (tag === 10) return 2;
    if (tag === 11 || tag === 12 || tag === 13) return 8 * type.at(-1);
    if (tag === 14) return choiceBits(type[1]);
    if (tag === 15) return 1 + this.width(type[1], path);
    if (tag === 16 || tag === 20) return 1 + Math.max(
      this.width(type[1], path), this.width(type[2], path));
    if (tag === 17) return type[1].reduce((sum, item) => sum + this.width(item, path), 0);
    if (tag === 18) return this.width(type[1], path) * type[2];
    if (tag === 19) return counterBits(type[2]) + this.width(type[1], path) * type[2];
    if (tag === 21) {
      const entry = this.declarations.get(type[1]);
      const variantCase = entry?.declaration.body.find(([stableTag]) => stableTag === type[2]);
      if (!variantCase) fail("0705", path);
      return (variantCase[1].payload ?? []).reduce((sum, [, item]) =>
        sum + this.width(this.normalize(item, entry.module, path)), 0);
    }
    if (tag === 22) {
      const entry = this.declarations.get(type[1]);
      if (!entry) fail("0700", path);
      const declaration = entry.declaration;
      if (declaration.tag === 0 || declaration.tag === 1) {
        return this.width(this.normalize(declaration.body, entry.module, path), path);
      }
      if (declaration.tag === 2) return declaration.body.reduce((sum, [, item]) =>
        sum + this.width(this.normalize(item, entry.module, path), path), 0);
      const maximumTag = declaration.body.reduce((maximum, [stableTag]) =>
        Math.max(maximum, stableTag), 0);
      const payload = declaration.body.reduce((maximum, [, variantCase]) => {
        const bits = (variantCase.payload ?? []).reduce((sum, [, item]) =>
          sum + this.width(this.normalize(item, entry.module, path), path), 0);
        return Math.max(maximum, bits);
      }, 0);
      return tagBits(maximumTag) + payload;
    }
    fail("0100", path);
  }

  resolveFunction(module, reference, path) {
    return this.resolveReference(module, reference, "functions", path);
  }

  field(module, fieldReference, recordType, path) {
    const [owner, fieldIndex] = fieldReference;
    if (owner[0] !== 0) fail("0701", path);
    const ref = this.resolveReference(module, owner[1], "types", `${path}/owner`);
    const declaration = ref.value[1];
    if (declaration.tag !== 2) fail("0701", path);
    const expectedOwner = [22, declKey(ref.module, ref.index)];
    if (!same(recordType, expectedOwner)) fail("0704", path);
    if (fieldIndex >= declaration.body.length) fail("0703", path);
    return this.normalize(declaration.body[fieldIndex][1], ref.module, path);
  }

  constructorInfo(module, constructor, path) {
    const [owner, stableTag] = constructor;
    if (owner[0] === 0) {
      const ref = this.resolveReference(module, owner[1], "types", `${path}/owner`);
      if (ref.value[1].tag !== 3) fail("0701", path);
      const variantCase = ref.value[1].body.find(([tag]) => tag === stableTag);
      if (!variantCase) fail("0705", path);
      const payload = variantCase[1].payload === null ? null :
        [21, declKey(ref.module, ref.index), stableTag];
      return { owner: [22, declKey(ref.module, ref.index)], payload };
    }
    if (owner[0] === 1) return { owner: [15, this.normalize(owner[1], module, path)],
      payload: stableTag === 0 ? null : stableTag === 1
        ? this.normalize(owner[1], module, path) : fail("0705", path) };
    if (owner[0] === 2 || owner[0] === 3) {
      if (stableTag > 1) fail("0705", path);
      const left = this.normalize(owner[1], module, path);
      const right = this.normalize(owner[2], module, path);
      return { owner: [owner[0] === 2 ? 16 : 20, left, right],
        payload: stableTag === 0 ? left : right };
    }
    if (stableTag > 3) fail("0705", path);
    return { owner: [10], payload: null };
  }

  checkBlock(block, module, environment, expectedParameters, expectedResult, path) {
    const parameters = block.parameters.map((type, index) =>
      this.normalize(type, module, `${path}/parameters/${index}`));
    if (!same(parameters, expectedParameters)) fail("080e", `${path}/parameters`);
    const result = this.normalize(block.result, module, `${path}/result`);
    if (!same(result, expectedResult)) fail("0804", `${path}/result`);
    return this.infer(block.body, module, [...parameters].reverse().concat(environment),
      `${path}/body`);
  }

  infer(expression, module, environment, path) {
    const term = expression.term;
    const tag = term[0];
    let inferred;
    if (tag === 0) inferred = [0];
    else if (tag === 1) inferred = [1];
    else if (tag === 2) inferred = [term[1] + 2];
    else if (tag === 3) inferred = [11, term[1].length];
    else if (tag === 4) {
      if (term[1] >= environment.length) fail("0702", `${path}/term/reference`);
      inferred = environment[term[1]];
    } else if (tag === 7) {
      const record = this.infer(term[1], module, environment, `${path}/term/record`);
      inferred = this.field(module, term[2], record.type, `${path}/term/field`);
    } else if (tag === 8) {
      const ref = this.resolveReference(module, term[1][0], "types", `${path}/term/case`);
      if (ref.value[1].tag !== 3) fail("0701", `${path}/term/case`);
      const variantCase = ref.value[1].body.find(([stableTag]) => stableTag === term[1][1]);
      if (!variantCase) fail("0705", `${path}/term/case`);
      if (term[2].length !== (variantCase[1].payload ?? []).length) {
        fail("0806", `${path}/term/fields`);
      }
      inferred = [22, declKey(ref.module, ref.index)];
      return this.finishExpression(expression, inferred, module, path,
        { constructor: [declKey(ref.module, ref.index), term[1][1]] });
    } else if (tag === 14) {
      const left = this.infer(term[1], module, environment, `${path}/term/left`);
      const right = this.infer(term[2], module, environment, `${path}/term/right`);
      if (!same(left.type, right.type)) fail("0801", path);
      inferred = [1];
    } else if (tag === 26) {
      const ref = this.resolveFunction(module, term[1], `${path}/term/function`);
      const body = ref.value[1];
      if (term[2].length !== body.parameters.length) fail("0802", `${path}/term/arguments`);
      term[2].forEach((argument, index) => {
        const actual = this.infer(argument, module, environment,
          `${path}/term/arguments/${index}`).type;
        const expected = this.normalize(body.parameters[index], ref.module,
          `${path}/term/arguments/${index}`);
        if (!same(actual, expected)) fail("0803", `${path}/term/arguments/${index}`);
      });
      inferred = this.normalize(body.result, ref.module, `${path}/term/result`);
    } else if (tag === 31) {
      const collection = this.infer(term[1], module, environment,
        `${path}/term/collection`).type;
      if (collection[0] !== 18 && collection[0] !== 19) fail("080e", path);
      const item = collection[1];
      const block = this.checkBlock(term[2], module, environment, [item], [1],
        `${path}/term/block`);
      if (!same(block.type, [1])) fail("0804", `${path}/term/block/body`);
      inferred = [16, [15, item], [0]];
    } else fail("0904", `${path}/term`);
    return this.finishExpression(expression, inferred, module, path);
  }

  finishExpression(expression, inferred, module, path, extra = {}) {
    const claimed = this.normalize(expression.claimedType, module, `${path}/claimed_type`);
    if (!same(claimed, inferred)) fail("0800", `${path}/claimed_type`);
    return { type: inferred, ...extra };
  }

  checkKernel(expression, module, environment, accepted, rejection, order, floor, path) {
    const tag = expression[0];
    if (tag === 0) {
      const value = this.infer(expression[1], module, environment, `${path}/value`);
      if (!same(value.type, accepted)) fail("0a02", path);
    } else if (tag === 1) {
      const reason = this.infer(expression[1], module, environment, `${path}/reason`);
      this.checkRejection(reason, expression[2], rejection, order, floor, path);
    } else if (tag === 2) {
      const condition = this.infer(expression[1], module, environment, `${path}/condition`);
      if (!same(condition.type, [1])) fail("0801", `${path}/condition`);
      const reason = this.infer(expression[2], module, environment, `${path}/rejection`);
      this.checkRejection(reason, expression[3], rejection, order, floor, path);
      this.checkKernel(expression[4], module, environment, accepted, rejection, order,
        expression[3] + 1, `${path}/continuation`);
    } else if (tag === 3) {
      const value = this.infer(expression[1], module, environment, `${path}/value`);
      this.checkKernel(expression[2], module, [value.type, ...environment], accepted,
        rejection, order, floor, `${path}/body`);
    } else if (tag === 5) {
      const scrutinee = this.infer(expression[1], module, environment,
        `${path}/scrutinee`);
      const seen = [];
      for (let index = 0; index < expression[2].length; ++index) {
        const [constructor, arm] = expression[2][index];
        const info = this.constructorInfo(module, constructor, `${path}/arms/${index}`);
        if (!same(info.owner, scrutinee.type)) fail("0706", `${path}/arms/${index}`);
        seen.push(constructor[1]);
        const armEnvironment = info.payload === null ? environment :
          [info.payload, ...environment];
        this.checkKernel(arm, module, armEnvironment, accepted, rejection, order,
          floor, `${path}/arms/${index}/body`);
      }
      const expected = this.constructorTags(scrutinee.type);
      if (!same(seen, expected)) fail("0808", `${path}/arms`);
    } else fail("0904", path);
  }

  constructorTags(type) {
    if (type[0] === 15 || type[0] === 16 || type[0] === 20) return [0, 1];
    if (type[0] === 10) return [0, 1, 2, 3];
    if (type[0] === 22) return this.declarations.get(type[1]).declaration.body
      .map(([stableTag]) => stableTag);
    return [];
  }

  checkRejection(reason, index, rejection, order, floor, path) {
    if (!same(reason.type, rejection)) fail("0a03", path);
    if (index >= order.length) fail("0a06", path);
    if (index < floor) fail("0a08", path);
    const expected = order[index];
    const ref = this.resolveReference(this.currentModule, expected[0], "types", path);
    const expectedConstructor = [declKey(ref.module, ref.index), expected[1]];
    if (!same(reason.constructor, expectedConstructor)) fail("0a07", path);
  }

  analyzeExpr(expression, module, environment, base, path) {
    const result = this.normalize(expression.claimedType, module, path);
    const resultBits = this.width(result, path);
    const term = expression.term;
    const tag = term[0];
    const leaf = () => ({ steps: 1, live: base + resultBits, depth: 1, workspace: 0,
      type: result });
    if (tag <= 4 || tag === 8) return leaf();
    if (tag === 7) {
      const child = this.analyzeExpr(term[1], module, environment, base, path);
      return { steps: 1 + child.steps,
        live: Math.max(child.live, base + this.width(child.type) + resultBits),
        depth: 1 + child.depth, workspace: child.workspace, type: result };
    }
    if (tag === 14) return this.analyzeStrict(term.slice(1), result, module,
      environment, base, path);
    if (tag === 26) {
      let retained = 0; let steps = 1; let live = base; let depth = 1; let workspace = 0;
      for (const argument of term[2]) {
        const child = this.analyzeExpr(argument, module, environment, base + retained, path);
        steps += child.steps; live = Math.max(live, child.live);
        depth = Math.max(depth, 1 + child.depth); workspace = Math.max(workspace, child.workspace);
        retained += this.width(child.type);
      }
      const ref = this.resolveFunction(module, term[1], path);
      const callee = this.callableBounds.get(callableKey(ref.module, ref.index));
      if (!callee) fail("0d04", path);
      steps += callee.steps; live = Math.max(live, base + callee.live);
      depth = Math.max(depth, 1 + callee.depth); workspace = Math.max(workspace, callee.workspace);
      return { steps, live, depth, workspace, type: result };
    }
    if (tag === 31) {
      const collection = this.analyzeExpr(term[1], module, environment, base, path);
      const collectionBits = this.width(collection.type);
      const capacity = collection.type[2];
      const item = collection.type[1];
      const itemBits = this.width(item);
      const blockBase = base + collectionBits + itemBits;
      const block = this.analyzeExpr(term[2].body, module, [item, ...environment],
        blockBase, path);
      const intrinsicWorkspace = counterBits(capacity) + 2 + itemBits;
      return { steps: 1 + collection.steps + capacity * (1 + block.steps),
        live: Math.max(collection.live, block.live,
          base + collectionBits + resultBits),
        depth: Math.max(1 + collection.depth, 2 + block.depth),
        workspace: Math.max(collection.workspace, intrinsicWorkspace + block.workspace),
        type: result };
    }
    fail("0904", path);
  }

  analyzeStrict(children, result, module, environment, base, path) {
    let retained = 0; let steps = 1; let live = base; let depth = 1; let workspace = 0;
    for (const expression of children) {
      const child = this.analyzeExpr(expression, module, environment, base + retained, path);
      steps += child.steps; live = Math.max(live, child.live);
      depth = Math.max(depth, 1 + child.depth); workspace = Math.max(workspace, child.workspace);
      retained += this.width(child.type);
    }
    live = Math.max(live, base + retained + this.width(result));
    return { steps, live, depth, workspace, type: result };
  }

  analyzeKernel(expression, module, environment, base, result, path) {
    const resultBits = this.width(result);
    const tag = expression[0];
    if (tag === 0 || tag === 1) {
      const child = this.analyzeExpr(expression[1], module, environment, base, path);
      return { steps: 1 + child.steps,
        live: Math.max(child.live, base + this.width(child.type) + resultBits),
        depth: 1 + child.depth, workspace: child.workspace };
    }
    if (tag === 2) {
      const condition = this.analyzeExpr(expression[1], module, environment, base, path);
      const rejection = this.analyzeExpr(expression[2], module, environment, base, path);
      const continuation = this.analyzeKernel(expression[4], module, environment, base,
        result, path);
      return { steps: 1 + condition.steps + Math.max(rejection.steps, continuation.steps),
        live: Math.max(condition.live, rejection.live,
          base + this.width(rejection.type) + resultBits, continuation.live),
        depth: 1 + Math.max(condition.depth, rejection.depth, continuation.depth),
        workspace: Math.max(condition.workspace, rejection.workspace, continuation.workspace) };
    }
    if (tag === 3) {
      const value = this.analyzeExpr(expression[1], module, environment, base, path);
      const valueBits = this.width(value.type);
      const body = this.analyzeKernel(expression[2], module, [value.type, ...environment],
        base + valueBits, result, path);
      return { steps: 1 + value.steps + body.steps, live: Math.max(value.live, body.live),
        depth: 1 + Math.max(value.depth, body.depth),
        workspace: Math.max(value.workspace, body.workspace) };
    }
    if (tag === 5) {
      const scrutinee = this.analyzeExpr(expression[1], module, environment, base, path);
      const scrutineeBits = this.width(scrutinee.type);
      let steps = 0; let live = 0; let depth = 0; let workspace = 0;
      for (const [constructor, arm] of expression[2]) {
        const info = this.constructorInfo(module, constructor, path);
        const payloadBits = info.payload === null ? 0 : this.width(info.payload);
        const armEnvironment = info.payload === null ? environment : [info.payload, ...environment];
        const resultCost = this.analyzeKernel(arm, module, armEnvironment,
          base + scrutineeBits + payloadBits, result, path);
        steps = Math.max(steps, resultCost.steps); live = Math.max(live, resultCost.live);
        depth = Math.max(depth, resultCost.depth); workspace = Math.max(workspace, resultCost.workspace);
      }
      return { steps: 1 + scrutinee.steps + steps,
        live: Math.max(scrutinee.live, live), depth: 1 + Math.max(scrutinee.depth, depth),
        workspace: Math.max(scrutinee.workspace, workspace) };
    }
    fail("0904", path);
  }

  compareBounds(actual, stored, declared, path) {
    const reasons = ["0b01", "0b02", "0b03", "0b04"];
    const values = [actual.steps, actual.live, actual.depth, actual.workspace];
    values.forEach((value, index) => {
      if (value !== stored[index]) fail(reasons[index], `${path}/exact/${index}`);
      if (value > declared[index]) fail("0b05", `${path}/declared/${index}`);
    });
  }

  check() {
    const orderedModules = [];
    const visited = new Set();
    const visit = (module) => {
      const key = identityKey(module.identity);
      if (visited.has(key)) return;
      for (const [importIdentity] of module.imports) {
        visit(this.byIdentity.get(identityKey(importIdentity)));
      }
      visited.add(key);
      orderedModules.push(module);
    };
    for (const module of this.modules) visit(module);
    for (const module of orderedModules) {
      this.currentModule = module;
      for (const index of module.derivations.functionOrder) {
        const body = module.functions[index][1];
        const parameters = body.parameters.map((type) => this.normalize(type, module));
        const result = this.normalize(body.result, module);
        const inferred = this.infer(body.body, module, [...parameters].reverse(),
          `module/functions/${index}/body`);
        if (!same(inferred.type, result)) fail("0804", `module/functions/${index}/result`);
        const base = parameters.reduce((sum, type) => sum + this.width(type), 0);
        const inner = this.analyzeExpr(body.body, module, [...parameters].reverse(), base,
          `module/functions/${index}/body`);
        const actual = { steps: 1 + inner.steps, live: inner.live,
          depth: 1 + inner.depth, workspace: inner.workspace };
        this.compareBounds(actual, body.exact, body.declared, `module/functions/${index}`);
        this.callableBounds.set(callableKey(module, index), actual);
      }
      for (let index = 0; index < module.kernels.length; ++index) {
        const body = module.kernels[index][1];
        const parameters = body.parameters.map((type) => this.normalize(type, module));
        const result = this.normalize(body.result, module);
        if (result[0] !== 20) fail("0a02", `module/kernels/${index}/result`);
        const rejectionTags = [];
        for (let orderIndex = 0; orderIndex < body.rejectionOrder.length; ++orderIndex) {
          const variant = body.rejectionOrder[orderIndex];
          const ref = this.resolveReference(module, variant[0], "types",
            `module/kernels/${index}/rejection_order/${orderIndex}`);
          if (!same([22, declKey(ref.module, ref.index)], result[2])) {
            fail("0a03", `module/kernels/${index}/rejection_order/${orderIndex}`);
          }
          if (rejectionTags.includes(variant[1])) {
            fail("0a05", `module/kernels/${index}/rejection_order/${orderIndex}`);
          }
          rejectionTags.push(variant[1]);
        }
        if (!same([...rejectionTags].sort((a, b) => a - b),
          [...this.constructorTags(result[2])].sort((a, b) => a - b))) {
          fail("0a04", `module/kernels/${index}/rejection_order`);
        }
        this.checkKernel(body.body, module, [...parameters].reverse(), result[1], result[2],
          body.rejectionOrder, 0, `module/kernels/${index}/body`);
        const base = parameters.reduce((sum, type) => sum + this.width(type), 0);
        const inner = this.analyzeKernel(body.body, module, [...parameters].reverse(), base,
          result, `module/kernels/${index}/body`);
        const actual = { steps: 1 + inner.steps, live: inner.live,
          depth: 1 + inner.depth, workspace: inner.workspace };
        this.compareBounds(actual, body.exact, body.declared, `module/kernels/${index}`);
      }
    }
    return true;
  }
}

export const checkTypedCore = (decoded) => new TypedCoreChecker(decoded).check();
