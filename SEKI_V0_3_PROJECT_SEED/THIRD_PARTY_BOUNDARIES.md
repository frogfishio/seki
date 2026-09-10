# Third-party boundaries

Seki v0.3 pins Lean 4.30.0, Rocq 9.2.0 and CompCert 3.18 as formal foundations.
This seed does not contain or license those projects.

The new project must bind exact dependency sources and review every license
before downloading, vendoring, redistributing or using a dependency in a
commercial product. In particular, do not assume that the public CompCert
distribution grants unrestricted commercial redistribution or use.

The native C compiler, assembler, linker, runtime and platform remain explicit
trusted premises in the initial profile unless a later qualified profile
removes them.
