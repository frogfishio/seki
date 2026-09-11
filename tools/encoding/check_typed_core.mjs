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
const counterBits = (length) => choiceBits(length + 1);
const tagBits = (tag) => tag === 0 ? 0 : Math.floor(Math.log2(tag)) + 1;
const C11_BOUNDED_PROFILE = [1048576, 32, 4096, 65536, 256, 32,
  [16777216, 8388608, 256, 8388608]];
const MAX_NAT = 0xffffffff;
const checkedNat = (value, path = "bounds") => {
  if (!Number.isSafeInteger(value) || value < 0 || value > MAX_NAT) fail("0b00", path);
  return value;
};
const checkedAdd = (left, right, path = "bounds") =>
  checkedNat(checkedNat(left, path) + checkedNat(right, path), path);
const checkedMul = (left, right, path = "bounds") => {
  checkedNat(left, path); checkedNat(right, path);
  if (left !== 0 && right > Math.floor(MAX_NAT / left)) fail("0b00", path);
  return left * right;
};

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
    this.callableDepth = new Map();
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
    if (tag === 15 || tag === 18) {
      return [tag, this.normalize(type[1], module, `${path}/item`, expanding), ...type.slice(2)];
    }
    if (tag === 16 || tag === 19) return [tag,
      this.normalize(type[1], module, `${path}/left`, expanding),
      this.normalize(type[2], module, `${path}/right`, expanding)];
    if (tag === 17) return [tag, type[1].map((item, index) =>
      this.normalize(item, module, `${path}/items/${index}`, expanding))];
    if (tag === 20) {
      const owner = this.resolveReference(module, type[1][0], "types", `${path}/case`);
      return [tag, declKey(owner.module, owner.index), type[1][1]];
    }
    if (tag === 21) {
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
    if (tag === 11 || tag === 12 || tag === 13) return checkedMul(8, type.at(-1), path);
    if (tag === 14) return choiceBits(type[1]);
    if (tag === 15) return checkedAdd(1, this.width(type[1], path), path);
    if (tag === 16 || tag === 19) return checkedAdd(1, Math.max(
      this.width(type[1], path), this.width(type[2], path)), path);
    if (tag === 17) return type[1].reduce((sum, item) =>
      checkedAdd(sum, this.width(item, path), path), 0);
    if (tag === 18) return checkedMul(this.width(type[1], path), type[2], path);
    if (tag === 20) {
      const entry = this.declarations.get(type[1]);
      const variantCase = entry?.declaration.body.find(([stableTag]) => stableTag === type[2]);
      if (!variantCase) fail("0705", path);
      return (variantCase[1].payload ?? []).reduce((sum, [, item]) =>
        checkedAdd(sum, this.width(this.normalize(item, entry.module, path), path), path), 0);
    }
    if (tag === 21) {
      const entry = this.declarations.get(type[1]);
      if (!entry) fail("0700", path);
      const declaration = entry.declaration;
      if (declaration.tag === 0 || declaration.tag === 1) {
        return this.width(this.normalize(declaration.body, entry.module, path), path);
      }
      if (declaration.tag === 2) return declaration.body.reduce((sum, [, item]) =>
        checkedAdd(sum, this.width(this.normalize(item, entry.module, path), path), path), 0);
      const maximumTag = declaration.body.reduce((maximum, [stableTag]) =>
        Math.max(maximum, stableTag), 0);
      const payload = declaration.body.reduce((maximum, [, variantCase]) => {
        const bits = (variantCase.payload ?? []).reduce((sum, [, item]) =>
          checkedAdd(sum, this.width(this.normalize(item, entry.module, path), path), path), 0);
        return Math.max(maximum, bits);
      }, 0);
      return checkedAdd(tagBits(maximumTag), payload, path);
    }
    fail("0100", path);
  }

  validateTypeFormation(type, module, path, allowVariantPayload = false) {
    const tag = type[0];
    if ((tag === 11 && type[1] === 0) || (tag === 17 && type[1].length === 0) ||
      (tag === 18 && type[2] === 0)) fail("0608", path);
    if (tag === 13 && type[2] !== 32) fail("0601", path);
    if (tag === 14 && type[1] === 0) fail("0600", path);
    if (tag === 20) {
      if (!allowVariantPayload) fail("0604", path);
      const ref = this.resolveReference(module, type[1][0], "types", path);
      const variantCase = ref.value[1].body?.find(([stableTag]) => stableTag === type[1][1]);
      if (!variantCase || variantCase[1].payload === null) fail("0604", path);
    }
    if (tag === 21) {
      const ref = this.resolveReference(module, type[1], "types", path);
      if (ref.value[1].tag === 0) fail("0606", path);
    }
    if (tag === 15 || tag === 18) {
      this.validateTypeFormation(type[1], module, `${path}/item`, allowVariantPayload);
    } else if (tag === 16 || tag === 19) {
      this.validateTypeFormation(type[1], module, `${path}/left`, allowVariantPayload);
      this.validateTypeFormation(type[2], module, `${path}/right`, allowVariantPayload);
    } else if (tag === 17) {
      type[1].forEach((item, index) => this.validateTypeFormation(item, module,
        `${path}/items/${index}`, allowVariantPayload));
    }
  }

  localTypeReferences(type, result = new Set()) {
    if (type[0] === 21 && type[1][0] === 0) result.add(type[1][1]);
    if (type[0] === 15 || type[0] === 18) {
      this.localTypeReferences(type[1], result);
    } else if (type[0] === 16 || type[0] === 19) {
      this.localTypeReferences(type[1], result); this.localTypeReferences(type[2], result);
    } else if (type[0] === 17) {
      for (const item of type[1]) this.localTypeReferences(item, result);
    }
    return result;
  }

  validateDeclarationGraph(module) {
    const visiting = new Set(); const complete = new Set();
    const visit = (index) => {
      if (visiting.has(index)) fail("0602", `module/types/${index}`);
      if (complete.has(index)) return;
      if (index >= module.types.length) fail("0700", `module/types/${index}`);
      visiting.add(index);
      for (const type of module.types[index][1].types) {
        for (const dependency of this.localTypeReferences(type)) visit(dependency);
      }
      visiting.delete(index); complete.add(index);
    };
    module.types.forEach((_, index) => visit(index));
  }

  resolveFunction(module, reference, path) {
    return this.resolveReference(module, reference, "functions", path);
  }

  field(module, fieldReference, recordType, path) {
    const [owner, fieldIndex] = fieldReference;
    if (owner[0] === 0) {
      const ref = this.resolveReference(module, owner[1], "types", `${path}/owner`);
      const declaration = ref.value[1];
      if (declaration.tag !== 2) fail("0701", path);
      const expectedOwner = [21, declKey(ref.module, ref.index)];
      if (!same(recordType, expectedOwner)) fail("0704", path);
      if (fieldIndex >= declaration.body.length) fail("0703", path);
      return this.normalize(declaration.body[fieldIndex][1], ref.module, path);
    }
    const ref = this.resolveReference(module, owner[1][0], "types", `${path}/owner`);
    const declaration = ref.value[1];
    if (declaration.tag !== 3) fail("0701", path);
    const variantCase = declaration.body.find(([tag]) => tag === owner[1][1]);
    if (!variantCase || variantCase[1].payload === null) fail("0705", path);
    const expectedOwner = [20, declKey(ref.module, ref.index), owner[1][1]];
    if (!same(recordType, expectedOwner)) fail("0704", path);
    if (fieldIndex >= variantCase[1].payload.length) fail("0703", path);
    return this.normalize(variantCase[1].payload[fieldIndex][1], ref.module, path);
  }

  constructorInfo(module, constructor, path) {
    const [owner, stableTag] = constructor;
    if (owner[0] === 0) {
      const ref = this.resolveReference(module, owner[1], "types", `${path}/owner`);
      if (ref.value[1].tag !== 3) fail("0701", path);
      const variantCase = ref.value[1].body.find(([tag]) => tag === stableTag);
      if (!variantCase) fail("0705", path);
      const payload = variantCase[1].payload === null ? null :
        [20, declKey(ref.module, ref.index), stableTag];
      return { owner: [21, declKey(ref.module, ref.index)], payload };
    }
    if (owner[0] === 1) return { owner: [15, this.normalize(owner[1], module, path)],
      payload: stableTag === 0 ? null : stableTag === 1
        ? this.normalize(owner[1], module, path) : fail("0705", path) };
    if (owner[0] === 2 || owner[0] === 3) {
      if (stableTag > 1) fail("0705", path);
      const left = this.normalize(owner[1], module, path);
      const right = this.normalize(owner[2], module, path);
      return { owner: [owner[0] === 2 ? 16 : 19, left, right],
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
    } else if (tag === 5) {
      const value = this.infer(term[1], module, environment, `${path}/term/value`);
      inferred = this.infer(term[2], module, [value.type, ...environment],
        `${path}/term/body`).type;
    } else if (tag === 6) {
      const ref = this.resolveReference(module, term[1], "types", `${path}/term/type`);
      const declaration = ref.value[1];
      if (declaration.tag !== 2) fail("0701", `${path}/term/type`);
      if (term[2].length !== declaration.body.length) fail("0805", `${path}/term/fields`);
      for (let index = 0; index < term[2].length; ++index) {
        const [fieldReference, value] = term[2][index];
        const owner = [21, declKey(ref.module, ref.index)];
        const fieldType = this.field(module, fieldReference, owner,
          `${path}/term/fields/${index}`);
        if (fieldReference[1] !== index) fail("0805", `${path}/term/fields/${index}`);
        const actual = this.infer(value, module, environment,
          `${path}/term/fields/${index}/value`).type;
        if (!same(actual, fieldType)) fail("0805", `${path}/term/fields/${index}/value`);
      }
      inferred = [21, declKey(ref.module, ref.index)];
    } else if (tag === 7) {
      const record = this.infer(term[1], module, environment, `${path}/term/record`);
      inferred = this.field(module, term[2], record.type, `${path}/term/field`);
    } else if (tag === 8) {
      const ref = this.resolveReference(module, term[1][0], "types", `${path}/term/case`);
      if (ref.value[1].tag !== 3) fail("0701", `${path}/term/case`);
      const variantCase = ref.value[1].body.find(([stableTag]) => stableTag === term[1][1]);
      if (!variantCase) fail("0705", `${path}/term/case`);
      const payload = variantCase[1].payload ?? [];
      if (term[2].length !== payload.length) {
        fail("0806", `${path}/term/fields`);
      }
      for (let index = 0; index < payload.length; ++index) {
        if (term[2][index][0] !== payload[index][0]) {
          fail("0806", `${path}/term/fields/${index}/key`);
        }
        const actual = this.infer(term[2][index][1], module, environment,
          `${path}/term/fields/${index}/value`).type;
        const expected = this.normalize(payload[index][1], ref.module,
          `${path}/term/fields/${index}/value`);
        if (!same(actual, expected)) fail("0806", `${path}/term/fields/${index}/value`);
      }
      inferred = [21, declKey(ref.module, ref.index)];
      return this.finishExpression(expression, inferred, module, path,
        { constructor: [declKey(ref.module, ref.index), term[1][1]] });
    } else if (tag === 9) {
      inferred = [17, term[1].map((item, index) => this.infer(item, module,
        environment, `${path}/term/items/${index}`).type)];
    } else if (tag === 10) {
      inferred = [15, this.normalize(term[1], module, `${path}/term/item_type`)];
    } else if (tag === 11) {
      inferred = [15, this.infer(term[1], module, environment,
        `${path}/term/value`).type];
    } else if (tag === 12) {
      inferred = [16, this.infer(term[2], module, environment,
        `${path}/term/value`).type,
      this.normalize(term[1], module, `${path}/term/error_type`)];
    } else if (tag === 13) {
      inferred = [16, this.normalize(term[1], module, `${path}/term/ok_type`),
        this.infer(term[2], module, environment, `${path}/term/error`).type];
    } else if (tag === 14 || tag === 15) {
      const left = this.infer(term[1], module, environment, `${path}/term/left`);
      const right = this.infer(term[2], module, environment, `${path}/term/right`);
      if (!same(left.type, right.type)) fail("0801", path);
      inferred = [1];
    } else if (tag === 16) {
      const value = this.infer(term[1], module, environment, `${path}/term/value`);
      if (!same(value.type, [1])) fail("0801", path);
      inferred = [1];
    } else if (tag === 17 || tag === 18) {
      const left = this.infer(term[1], module, environment, `${path}/term/left`);
      const right = this.infer(term[2], module, environment, `${path}/term/right`);
      if (!same(left.type, [1]) || !same(right.type, [1])) fail("0801", path);
      inferred = [1];
    } else if (tag === 19) {
      const left = this.infer(term[2], module, environment, `${path}/term/left`);
      const right = this.infer(term[3], module, environment, `${path}/term/right`);
      if (!same(left.type, right.type) || !this.isInteger(left.type)) fail("080a", path);
      inferred = [1];
    } else if (tag === 20) {
      const left = this.infer(term[3], module, environment, `${path}/term/left`);
      const right = this.infer(term[4], module, environment, `${path}/term/right`);
      if (!same(left.type, right.type) || !this.isInteger(left.type)) fail("080b", path);
      inferred = this.arithmeticResult(term[1], term[2], left.type);
    } else if (tag === 21) {
      const value = this.infer(term[3], module, environment, `${path}/term/value`);
      if (!this.isInteger(value.type)) fail("080b", path);
      if (value.type[0] < 6) fail("080d", path);
      inferred = this.arithmeticResult(term[1], 0, value.type);
    } else if (tag === 22) {
      const value = this.infer(term[3], module, environment, `${path}/term/value`);
      const count = this.infer(term[4], module, environment, `${path}/term/count`);
      if (!this.isInteger(value.type)) fail("080b", path);
      if (!same(count.type, [4])) fail("080c", path);
      inferred = [16, value.type, [10]];
    } else if (tag === 23) {
      const value = this.infer(term[3], module, environment, `${path}/term/value`);
      if (!this.isInteger(value.type)) fail("080b", path);
      const target = [term[2] + 2];
      inferred = term[1] === 0 ? [16, target, [10]] : target;
    } else if (tag === 24) {
      const condition = this.infer(term[1], module, environment, `${path}/term/condition`);
      const yes = this.infer(term[2], module, environment, `${path}/term/when_true`);
      const no = this.infer(term[3], module, environment, `${path}/term/when_false`);
      if (!same(condition.type, [1])) fail("0801", `${path}/term/condition`);
      if (!same(yes.type, no.type)) fail("0807", path);
      inferred = yes.type;
    } else if (tag === 25) {
      const scrutinee = this.infer(term[1], module, environment,
        `${path}/term/scrutinee`);
      const seen = [];
      let armType;
      for (let index = 0; index < term[2].length; ++index) {
        const [constructor, arm] = term[2][index];
        const info = this.constructorInfo(module, constructor, `${path}/term/arms/${index}`);
        if (!same(info.owner, scrutinee.type)) fail("0706", `${path}/term/arms/${index}`);
        seen.push(constructor[1]);
        const armEnvironment = info.payload === null ? environment : [info.payload, ...environment];
        const current = this.infer(arm, module, armEnvironment,
          `${path}/term/arms/${index}/body`).type;
        if (armType !== undefined && !same(current, armType)) {
          fail("0807", `${path}/term/arms/${index}/body`);
        }
        armType = current;
      }
      if (!same(seen, this.constructorTags(scrutinee.type))) fail("0808", `${path}/term/arms`);
      inferred = armType;
    } else if (tag === 27) {
      const collection = this.infer(term[1], module, environment,
        `${path}/term/collection`).type;
      const index = this.infer(term[2], module, environment, `${path}/term/index`).type;
      if (collection[0] !== 18 || !same(index, [4])) fail("080e", path);
      inferred = [15, collection[1]];
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
    } else if (tag === 28) {
      const collection = this.infer(term[1], module, environment,
        `${path}/term/collection`).type;
      if (collection[0] !== 18) fail("080e", path);
      const initial = this.infer(term[2], module, environment,
        `${path}/term/initial`).type;
      const block = this.checkBlock(term[3], module, environment,
        [initial, collection[1]], initial, `${path}/term/block`);
      if (!same(block.type, initial)) fail("0804", `${path}/term/block/body`);
      inferred = initial;
    } else if (tag === 29) {
      const collection = this.infer(term[1], module, environment,
        `${path}/term/collection`).type;
      if (collection[0] !== 18) fail("080e", path);
      const item = collection[1];
      const block = this.checkBlock(term[2], module, environment, [item], [1],
        `${path}/term/block`);
      if (!same(block.type, [1])) fail("0804", `${path}/term/block/body`);
      inferred = [16, [15, item], [0]];
    } else if (tag === 30 || tag === 31) {
      const collection = this.infer(term[1], module, environment,
        `${path}/term/collection`).type;
      if (collection[0] !== 18) fail("080e", path);
      const block = this.checkBlock(term[2], module, environment, [collection[1]], [1],
        `${path}/term/block`);
      if (!same(block.type, [1])) fail("0804", `${path}/term/block/body`);
      inferred = [1];
    } else if (tag === 32) {
      const collection = this.infer(term[1], module, environment,
        `${path}/term/collection`).type;
      if (collection[0] !== 18) fail("080e", path);
      const parameter = term[2].parameters;
      if (parameter.length !== 1) fail("080e", `${path}/term/block/parameters`);
      const item = this.normalize(parameter[0], module, `${path}/term/block/parameters/0`);
      if (!same(item, collection[1])) fail("080e", `${path}/term/block/parameters/0`);
      const mapped = this.normalize(term[2].result, module, `${path}/term/block/result`);
      const block = this.checkBlock(term[2], module, environment, [collection[1]], mapped,
        `${path}/term/block`);
      if (!same(block.type, mapped)) fail("0804", `${path}/term/block/body`);
      inferred = [18, mapped, collection[2]];
    } else fail("0904", `${path}/term`);
    return this.finishExpression(expression, inferred, module, path);
  }

  finishExpression(expression, inferred, module, path, extra = {}) {
    this.validateTypeFormation(expression.claimedType, module, `${path}/claimed_type`,
      inferred[0] === 20 && expression.claimedType[0] === 20);
    const claimed = this.normalize(expression.claimedType, module, `${path}/claimed_type`);
    if (!same(claimed, inferred)) fail("0800", `${path}/claimed_type`);
    return { type: inferred, ...extra };
  }

  isInteger(type) { return type.length === 1 && type[0] >= 2 && type[0] <= 9; }

  arithmeticResult(policy, operation, integerType) {
    const alwaysResult = operation === 3 || operation === 4;
    return policy === 0 || alwaysResult ? [16, integerType, [10]] : integerType;
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
    } else if (tag === 4) {
      const condition = this.infer(expression[1], module, environment, `${path}/condition`);
      if (!same(condition.type, [1])) fail("0801", `${path}/condition`);
      this.checkKernel(expression[2], module, environment, accepted, rejection, order,
        floor, `${path}/when_true`);
      this.checkKernel(expression[3], module, environment, accepted, rejection, order,
        floor, `${path}/when_false`);
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
    if (type[0] === 15 || type[0] === 16 || type[0] === 19) return [0, 1];
    if (type[0] === 10) return [0, 1, 2, 3];
    if (type[0] === 21) return this.declarations.get(type[1]).declaration.body
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
    if (tag <= 4 || tag === 10) return leaf();
    if (tag === 5) {
      const value = this.analyzeExpr(term[1], module, environment, base, path);
      const valueBits = this.width(value.type);
      const body = this.analyzeExpr(term[2], module, [value.type, ...environment],
        base + valueBits, path);
      return { steps: 1 + value.steps + body.steps, live: Math.max(value.live, body.live),
        depth: 1 + Math.max(value.depth, body.depth),
        workspace: Math.max(value.workspace, body.workspace), type: result };
    }
    if (tag === 6) return this.analyzeStrict(term[2].map(([, value]) => value),
      result, module, environment, base, path);
    if (tag === 8) return this.analyzeStrict(term[2].map(([, value]) => value),
      result, module, environment, base, path);
    if (tag === 7) {
      const child = this.analyzeExpr(term[1], module, environment, base, path);
      return { steps: 1 + child.steps,
        live: Math.max(child.live, base + this.width(child.type) + resultBits),
        depth: 1 + child.depth, workspace: child.workspace, type: result };
    }
    if (tag === 9) return this.analyzeStrict(term[1], result, module,
      environment, base, path);
    if (tag === 11) return this.analyzeStrict([term[1]], result, module,
      environment, base, path);
    if (tag === 12 || tag === 13) return this.analyzeStrict([term[2]], result, module,
      environment, base, path);
    if (tag === 14 || tag === 15) return this.analyzeStrict(term.slice(1), result, module,
      environment, base, path);
    if (tag === 16) return this.analyzeStrict([term[1]], result, module,
      environment, base, path);
    if (tag === 17 || tag === 18) {
      const left = this.analyzeExpr(term[1], module, environment, base, path);
      const right = this.analyzeExpr(term[2], module, environment, base, path);
      return { steps: 1 + left.steps + right.steps,
        live: Math.max(left.live, right.live), depth: 1 + Math.max(left.depth, right.depth),
        workspace: Math.max(left.workspace, right.workspace), type: result };
    }
    if (tag === 19) return this.analyzeStrict(term.slice(2), result, module,
      environment, base, path);
    if (tag === 20) return this.analyzeStrict(term.slice(3), result, module,
      environment, base, path);
    if (tag === 21) return this.analyzeStrict([term[3]], result, module,
      environment, base, path);
    if (tag === 22) return this.analyzeStrict(term.slice(3), result, module,
      environment, base, path);
    if (tag === 23) return this.analyzeStrict([term[3]], result, module,
      environment, base, path);
    if (tag === 24) {
      const condition = this.analyzeExpr(term[1], module, environment, base, path);
      const yes = this.analyzeExpr(term[2], module, environment, base, path);
      const no = this.analyzeExpr(term[3], module, environment, base, path);
      return { steps: 1 + condition.steps + Math.max(yes.steps, no.steps),
        live: Math.max(condition.live, yes.live, no.live),
        depth: 1 + Math.max(condition.depth, yes.depth, no.depth),
        workspace: Math.max(condition.workspace, yes.workspace, no.workspace), type: result };
    }
    if (tag === 25) {
      const scrutinee = this.analyzeExpr(term[1], module, environment, base, path);
      const scrutineeBits = this.width(scrutinee.type);
      let armSteps = 0; let armLive = 0; let armDepth = 0; let armWorkspace = 0;
      for (const [constructor, arm] of term[2]) {
        const info = this.constructorInfo(module, constructor, path);
        const payloadBits = info.payload === null ? 0 : this.width(info.payload);
        const armEnvironment = info.payload === null ? environment : [info.payload, ...environment];
        const cost = this.analyzeExpr(arm, module, armEnvironment,
          base + scrutineeBits + payloadBits, path);
        armSteps = Math.max(armSteps, cost.steps); armLive = Math.max(armLive, cost.live);
        armDepth = Math.max(armDepth, cost.depth);
        armWorkspace = Math.max(armWorkspace, cost.workspace);
      }
      return { steps: 1 + scrutinee.steps + armSteps,
        live: Math.max(scrutinee.live, armLive),
        depth: 1 + Math.max(scrutinee.depth, armDepth),
        workspace: Math.max(scrutinee.workspace, armWorkspace), type: result };
    }
    if (tag === 27) return this.analyzeStrict(term.slice(1), result,
      module, environment, base, path);
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
    if (tag === 28) return this.analyzeTraversal(expression, module, environment,
      base, path, "fold");
    if (tag === 29) {
      const collection = this.analyzeExpr(term[1], module, environment, base, path);
      const collectionBits = this.width(collection.type);
      const length = collection.type[2];
      const item = collection.type[1];
      const itemBits = this.width(item);
      const blockBase = base + collectionBits + itemBits;
      const block = this.analyzeExpr(term[2].body, module, [item, ...environment],
        blockBase, path);
      const intrinsicWorkspace = counterBits(length) + 2 + itemBits;
      return { steps: checkedAdd(checkedAdd(1, collection.steps, path),
          checkedMul(length, checkedAdd(1, block.steps, path), path), path),
        live: Math.max(collection.live, block.live,
          base + collectionBits + resultBits),
        depth: Math.max(1 + collection.depth, 2 + block.depth),
        workspace: Math.max(collection.workspace, intrinsicWorkspace + block.workspace),
        type: result };
    }
    if (tag >= 30 && tag <= 32) {
      const kinds = { 30: "all", 31: "any", 32: "map" };
      return this.analyzeTraversal(expression, module, environment, base, path, kinds[tag]);
    }
    fail("0904", path);
  }

  analyzeTraversal(expression, module, environment, base, path, kind) {
    const term = expression.term;
    const result = this.normalize(expression.claimedType, module, path);
    const collection = this.analyzeExpr(term[1], module, environment, base, path);
    const collectionBits = this.width(collection.type);
    const length = collection.type[2];
    const item = collection.type[1];
    const itemBits = this.width(item);
    let retained = collectionBits;
    let steps = 1 + collection.steps;
    let live = collection.live;
    let depth = 1 + collection.depth;
    let workspace = collection.workspace;
    let block;
    let intrinsicWorkspace;
    if (kind === "fold") {
      const initial = this.analyzeExpr(term[2], module, environment, base + retained, path);
      retained += this.width(initial.type); steps += initial.steps;
      live = Math.max(live, initial.live); depth = Math.max(depth, 1 + initial.depth);
      workspace = Math.max(workspace, initial.workspace);
      const parameterTypes = [initial.type, item];
      const parameterBits = parameterTypes.reduce((sum, type) => sum + this.width(type), 0);
      block = this.analyzeExpr(term[3].body, module,
        [...parameterTypes].reverse().concat(environment), base + retained + parameterBits, path);
      intrinsicWorkspace = counterBits(length) + this.width(initial.type);
    } else {
      const blockValue = term[2];
      const parameterBits = itemBits;
      block = this.analyzeExpr(blockValue.body, module, [item, ...environment],
        base + retained + parameterBits, path);
      if (kind === "all" || kind === "any") intrinsicWorkspace = counterBits(length) + 1;
      else if (kind === "map") intrinsicWorkspace = counterBits(length) + this.width(result);
      else intrinsicWorkspace = counterBits(length) + this.width(result);
    }
    steps = checkedAdd(steps,
      checkedMul(length, checkedAdd(1, block.steps, path), path), path);
    live = Math.max(live, block.live);
    depth = Math.max(depth, 2 + block.depth);
    workspace = Math.max(workspace, intrinsicWorkspace + block.workspace);
    if (kind === "all" || kind === "any") {
      live = Math.max(live, base + retained + this.width(result));
    }
    return { steps, live, depth, workspace, type: result };
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
    if (tag === 4) {
      const condition = this.analyzeExpr(expression[1], module, environment, base, path);
      const yes = this.analyzeKernel(expression[2], module, environment, base, result, path);
      const no = this.analyzeKernel(expression[3], module, environment, base, result, path);
      return { steps: 1 + condition.steps + Math.max(yes.steps, no.steps),
        live: Math.max(condition.live, yes.live, no.live),
        depth: 1 + Math.max(condition.depth, yes.depth, no.depth),
        workspace: Math.max(condition.workspace, yes.workspace, no.workspace) };
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
      checkedNat(value, `${path}/derived/${index}`);
      if (value !== stored[index]) fail(reasons[index], `${path}/exact/${index}`);
      if (value > declared[index]) fail("0b05", `${path}/declared/${index}`);
    });
  }

  checkModuleCeilings(module) {
    if (!same(module.profile, ["c11_bounded", 1])) fail("0b07", "module/profile");
    const declared = module.moduleBounds;
    for (let index = 0; index < 6; ++index) {
      if (declared[index] > C11_BOUNDED_PROFILE[index]) {
        fail("0b07", `module/bounds/${index}`);
      }
    }
    declared[6].forEach((value, index) => {
      if (value > C11_BOUNDED_PROFILE[6][index]) fail("0b07", `module/bounds/resources/${index}`);
    });
    const declarationCount = module.domains.length + module.types.length +
      module.functions.length + module.kernels.length;
    if (module.canonicalBytes.length > declared[0] || module.imports.length > declared[1] ||
      declarationCount > declared[2]) fail("0b06", "module/bounds");
    this.validateDeclarationGraph(module);
    module.types.forEach(([, declaration], declarationIndex) =>
      declaration.types.forEach((type, typeIndex) => {
        const path = `module/types/${declarationIndex}/${typeIndex}`;
        this.validateTypeFormation(type, module, path);
        const bits = this.width(this.normalize(type, module, path), path);
        if (bits > C11_BOUNDED_PROFILE[6][1]) fail("0607", path);
      }));
    module.types.forEach(([, declaration], declarationIndex) => {
      if (declaration.tag === 3) {
        if (declaration.body.length === 0) fail("0603", `module/types/${declarationIndex}`);
        const names = new Set();
        for (const [, variantCase] of declaration.body) {
          if (names.has(variantCase.name)) fail("0501", `module/types/${declarationIndex}`);
          names.add(variantCase.name);
        }
      }
    });
    for (const [kind, entries] of [["functions", module.functions], ["kernels", module.kernels]]) {
      entries.forEach(([, body], callableIndex) => {
        [...body.parameters, body.result].forEach((type, typeIndex) => {
          const path = `module/${kind}/${callableIndex}/types/${typeIndex}`;
          this.validateTypeFormation(type, module, path);
          const bits = this.width(this.normalize(type, module, path), path);
          if (bits > C11_BOUNDED_PROFILE[6][1]) fail("0607", path);
        });
        body.declared.forEach((value, index) => {
          if (value > declared[6][index]) fail("0b06",
            `module/${kind}/${callableIndex}/declared/${index}`);
        });
      });
    }
    let expressionNodes = 0;
    let maximumNesting = 0;
    for (const [, body] of module.functions) {
      const metrics = this.expressionMetrics(body.body);
      expressionNodes += metrics.count; maximumNesting = Math.max(maximumNesting, metrics.nesting);
    }
    for (const [, body] of module.kernels) {
      const metrics = this.kernelMetrics(body.body);
      expressionNodes += metrics.count; maximumNesting = Math.max(maximumNesting, metrics.nesting);
    }
    if (expressionNodes > declared[3] || maximumNesting > declared[4]) {
      fail("0b06", "module/bounds/structure");
    }
  }

  expressionMetrics(expression, depth = 1) {
    let count = 1; let nesting = depth;
    const walk = (value) => {
      if (value === null || value === undefined || Buffer.isBuffer(value)) return;
      if (typeof value === "object" && !Array.isArray(value) &&
        Object.hasOwn(value, "claimedType")) {
        const child = this.expressionMetrics(value, depth + 1);
        count += child.count; nesting = Math.max(nesting, child.nesting); return;
      }
      if (typeof value === "object" && !Array.isArray(value) &&
        Object.hasOwn(value, "parameters") && Object.hasOwn(value, "body")) {
        const child = this.expressionMetrics(value.body, depth + 1);
        count += child.count; nesting = Math.max(nesting, child.nesting); return;
      }
      if (Array.isArray(value)) for (const item of value) walk(item);
      else if (typeof value === "object") for (const item of Object.values(value)) walk(item);
    };
    walk(expression.term);
    return { count, nesting };
  }

  kernelMetrics(kernel, depth = 1) {
    let count = 1; let nesting = depth;
    const addExpression = (expression) => {
      const child = this.expressionMetrics(expression, depth + 1);
      count += child.count; nesting = Math.max(nesting, child.nesting);
    };
    const addKernel = (childKernel) => {
      const child = this.kernelMetrics(childKernel, depth + 1);
      count += child.count; nesting = Math.max(nesting, child.nesting);
    };
    switch (kernel[0]) {
      case 0: addExpression(kernel[1]); break;
      case 1: addExpression(kernel[1]); break;
      case 2: addExpression(kernel[1]); addExpression(kernel[2]); addKernel(kernel[4]); break;
      case 3: addExpression(kernel[1]); addKernel(kernel[2]); break;
      case 4: addExpression(kernel[1]); addKernel(kernel[2]); addKernel(kernel[3]); break;
      case 5:
        addExpression(kernel[1]);
        for (const [, arm] of kernel[2]) addKernel(arm);
        break;
    }
    return { count, nesting };
  }

  calledFunctions(value, result = []) {
    if (value === null || value === undefined || Buffer.isBuffer(value)) return result;
    if (Array.isArray(value)) {
      if (value[0] === 26 && Array.isArray(value[1])) result.push(value[1]);
      for (const item of value) this.calledFunctions(item, result);
    } else if (typeof value === "object") {
      for (const item of Object.values(value)) this.calledFunctions(item, result);
    }
    return result;
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
      this.checkModuleCeilings(module);
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
        const calls = this.calledFunctions(body.body.term);
        const callDepth = 1 + calls.reduce((maximum, reference) => {
          const ref = this.resolveFunction(module, reference, "module/call_depth");
          return Math.max(maximum, this.callableDepth.get(callableKey(ref.module, ref.index)) ?? 0);
        }, 0);
        this.callableDepth.set(callableKey(module, index), callDepth);
        if (callDepth > module.moduleBounds[5]) fail("0b08", `module/functions/${index}`);
      }
      for (let index = 0; index < module.kernels.length; ++index) {
        const body = module.kernels[index][1];
        const parameters = body.parameters.map((type) => this.normalize(type, module));
        const result = this.normalize(body.result, module);
        if (result[0] !== 19) fail("0a02", `module/kernels/${index}/result`);
        const rejectionTags = [];
        for (let orderIndex = 0; orderIndex < body.rejectionOrder.length; ++orderIndex) {
          const variant = body.rejectionOrder[orderIndex];
          const ref = this.resolveReference(module, variant[0], "types",
            `module/kernels/${index}/rejection_order/${orderIndex}`);
          if (!same([21, declKey(ref.module, ref.index)], result[2])) {
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
        if (body.publicationEligible &&
          (!module.claims.includes(7) || !module.theorems.includes(6))) {
          fail("0a0a", `module/kernels/${index}/publication_eligible`);
        }
        const base = parameters.reduce((sum, type) => sum + this.width(type), 0);
        const inner = this.analyzeKernel(body.body, module, [...parameters].reverse(), base,
          result, `module/kernels/${index}/body`);
        const actual = { steps: 1 + inner.steps, live: inner.live,
          depth: 1 + inner.depth, workspace: inner.workspace };
        this.compareBounds(actual, body.exact, body.declared, `module/kernels/${index}`);
        const callDepth = 1 + this.calledFunctions(body.body).reduce((maximum, reference) => {
          const ref = this.resolveFunction(module, reference, "module/call_depth");
          return Math.max(maximum, this.callableDepth.get(callableKey(ref.module, ref.index)) ?? 0);
        }, 0);
        if (callDepth > module.moduleBounds[5]) fail("0b08", `module/kernels/${index}`);
      }
    }
    return true;
  }
}

export const checkTypedCore = (decoded) => new TypedCoreChecker(decoded).check();
