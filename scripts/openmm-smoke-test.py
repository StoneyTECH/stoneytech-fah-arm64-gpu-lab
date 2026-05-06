#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
import traceback


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a small OpenMM platform smoke test.")
    parser.add_argument("--platform", default="CUDA", help="OpenMM platform to require and test")
    parser.add_argument("--particles", type=int, default=256, help="Number of particles in the toy system")
    parser.add_argument("--steps", type=int, default=100, help="Integrator steps to run")
    parser.add_argument("--precision", default="mixed", help="CUDA precision property when using CUDA")
    parser.add_argument(
        "--allow-missing-platform",
        action="store_true",
        help="Exit zero when the requested platform is not present",
    )
    return parser.parse_args()


def print_platform_inventory() -> list[str]:
    print(f"OpenMM version: {openmm.version.version}")
    print("Available platforms:")

    names = []
    for index in range(openmm.Platform.getNumPlatforms()):
        platform = openmm.Platform.getPlatform(index)
        name = platform.getName()
        names.append(name)
        print(f"- {name}")
        for prop in platform.getPropertyNames():
            try:
                value = platform.getPropertyDefaultValue(prop)
            except Exception as exc:
                value = f"<unavailable: {exc}>"
            print(f"  {prop}: {value}")
    return names


def build_chain_system(particles: int) -> tuple[openmm.System, unit.Quantity]:
    if particles < 2:
        raise ValueError("--particles must be at least 2")

    system = openmm.System()
    bond_force = openmm.HarmonicBondForce()

    for index in range(particles):
        system.addParticle(39.948 * unit.amu)
        if index:
            bond_force.addBond(index - 1, index, 0.1 * unit.nanometer, 1000.0 * unit.kilojoule_per_mole / unit.nanometer**2)

    system.addForce(bond_force)
    positions = [Vec3(index * 0.1, 0.0, 0.0) for index in range(particles)] * unit.nanometer
    return system, positions


def main() -> int:
    args = parse_args()

    global Vec3, openmm, unit
    try:
        import openmm
        from openmm import Vec3, unit
    except Exception as exc:
        print(f"OpenMM import failed: {exc}", file=sys.stderr)
        return 2

    platforms = print_platform_inventory()

    if args.platform not in platforms:
        print(f"{args.platform} platform not available")
        return 0 if args.allow_missing_platform else 1

    platform = openmm.Platform.getPlatformByName(args.platform)
    properties = {}
    if args.platform == "CUDA":
        properties["Precision"] = args.precision

    print(f"Selected platform: {args.platform}")
    print(f"Particles: {args.particles}")
    print(f"Steps: {args.steps}")
    print(f"Platform properties: {properties}")

    try:
        system, positions = build_chain_system(args.particles)
        integrator = openmm.VerletIntegrator(1.0 * unit.femtoseconds)
        context = openmm.Context(system, integrator, platform, properties)
        context.setPositions(positions)
        integrator.step(args.steps)

        state = context.getState(getEnergy=True, getPositions=True)
        energy = state.getPotentialEnergy()
        output_positions = state.getPositions(asNumpy=True)

        print("OpenMM smoke test completed")
        print(f"Potential energy: {energy}")
        print(f"Final position shape: {output_positions.shape}")
        return 0
    except Exception:
        print("OpenMM smoke test failed during platform execution", file=sys.stderr)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
