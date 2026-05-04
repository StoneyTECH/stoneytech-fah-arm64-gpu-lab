#!/usr/bin/env python3

import sys

try:
    import openmm
    from openmm import unit
except Exception as exc:
    print(f"OpenMM import failed: {exc}", file=sys.stderr)
    sys.exit(2)


def main() -> int:
    print(f"OpenMM version: {openmm.version.version}")
    print("Available platforms:")

    platforms = []
    for index in range(openmm.Platform.getNumPlatforms()):
        platform = openmm.Platform.getPlatform(index)
        platforms.append(platform.getName())
        print(f"- {platform.getName()}")

    if "CUDA" not in platforms:
        print("CUDA platform not available")
        return 1

    platform = openmm.Platform.getPlatformByName("CUDA")
    system = openmm.System()
    system.addParticle(39.948 * unit.amu)

    integrator = openmm.VerletIntegrator(1.0 * unit.femtoseconds)
    context = openmm.Context(system, integrator, platform)
    context.setPositions([[0.0, 0.0, 0.0]] * unit.nanometer)
    integrator.step(10)

    state = context.getState(getPositions=True)
    positions = state.getPositions(asNumpy=True)
    print("CUDA smoke test completed")
    print(f"Final position shape: {positions.shape}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
