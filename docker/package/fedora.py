# SPDX-FileCopyrightText: 2021 TQ Tezos <https://tqtezos.com/>
#
# SPDX-License-Identifier: LicenseRef-MIT-TQ
import os, shutil, subprocess

from typing import List

from .model import AbstractPackage
from .systemd import print_service_file


def build_fedora_package(
    pkg: AbstractPackage,
    build_deps: List[str],
    run_deps: List[str],
    is_source: bool,
):
    dir = f"{pkg.name}-{pkg.meta.version}"
    cwd = os.path.dirname(__file__)
    home = os.environ["HOME"]

    pkg.fetch_sources(dir)
    pkg.gen_makefile(f"{dir}/Makefile")
    pkg.gen_license(f"{dir}/LICENSE")
    for systemd_unit in pkg.systemd_units:
        if systemd_unit.service_file.service.environment_file is not None:
            systemd_unit.service_file.service.environment_file = (
                systemd_unit.service_file.service.environment_file.lower()
            )
        if systemd_unit.suffix is None:
            unit_name = f"{pkg.name}"
        else:
            unit_name = f"{pkg.name}-{systemd_unit.suffix}"
        out_path = (
            f"{dir}/{unit_name}@.service"
            if systemd_unit.instances is not None
            else f"{dir}/{unit_name}.service"
        )
        print_service_file(systemd_unit.service_file, out_path)
        if systemd_unit.config_file is not None:
            shutil.copy(
                f"{cwd}/defaults/{systemd_unit.config_file}",
                f"{dir}/{unit_name}.default",
            )
        if systemd_unit.startup_script is not None:
            dest_path = f"{dir}/{systemd_unit.startup_script}"
            source_script_name = (
                systemd_unit.startup_script
                if systemd_unit.startup_script_source is None
                else systemd_unit.startup_script_source
            )
            source_path = f"{cwd}/scripts/{source_script_name}"
            shutil.copy(source_path, dest_path)
        if systemd_unit.prestart_script is not None:
            dest_path = f"{dir}/{systemd_unit.prestart_script}"
            source_path = (
                f"{cwd}/scripts/{systemd_unit.prestart_script}"
                if systemd_unit.prestart_script_source is None
                else f"{cwd}/scripts/{systemd_unit.prestart_script_source}"
            )
            shutil.copy(source_path, dest_path)
    subprocess.run(["tar", "-czf", f"{dir}.tar.gz", dir], check=True)
    os.makedirs(f"{home}/rpmbuild/SPECS", exist_ok=True)
    os.makedirs(f"{home}/rpmbuild/SOURCES", exist_ok=True)
    pkg.gen_spec_file(
        build_deps + run_deps, run_deps, f"{home}/rpmbuild/SPECS/{pkg.name}.spec"
    )
    os.rename(f"{dir}.tar.gz", f"{home}/rpmbuild/SOURCES/{dir}.tar.gz")
    subprocess.run(
        [
            "rpmbuild",
            "-bs" if is_source else "-bb",
            f"{home}/rpmbuild/SPECS/{pkg.name}.spec",
        ],
        check=True,
    )

    subprocess.run(f"rm -rf {dir}", shell=True, check=True)
