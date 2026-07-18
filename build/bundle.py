import os

SRC_DIR = "src"
ENTRY_FILE = "init.lua"
OUT_DIR = "dist"
OUT_FILE = os.path.join(OUT_DIR, "NeroUI.lua")

def collect_modules(src_dir):
    modules = {}
    for root, _, files in os.walk(src_dir):
        for fname in files:
            if not fname.endswith(".lua"):
                continue
            full_path = os.path.join(root, fname)
            rel_path = os.path.relpath(full_path, src_dir)
            module_key = rel_path[:-4].replace(os.sep, "/")
            with open(full_path, "r", encoding="utf-8") as f:
                modules[module_key] = f.read()
    return modules


def build_modules_block(modules):
    parts = ["local Modules = {}\n"]
    for key in sorted(modules.keys()):
        source = modules[key]
        parts.append(f'Modules["{key}"] = function(...)\n{source}\nend\n')
    return "\n".join(parts)


def build_import_shim():
    return """
local Cache = {}

local function Import(path)
\tif Cache[path] then
\t\treturn Cache[path]
\tend

\tlocal loader = Modules[path]
\tassert(loader, ("NeroUI: module '%s' ga ketemu di bundle"):format(path))

\tlocal result = loader(Import)
\tCache[path] = result

\treturn result
end
"""


def strip_entry_bootstrap(entry_source):
    marker = 'local ScreenManager = Import("Core/ScreenManager")'
    idx = entry_source.find(marker)
    if idx == -1:
        raise RuntimeError(
            "Nggak nemu marker bootstrap di init.lua, cek ulang manual -- "
            "kemungkinan struktur init.lua kamu udah beda dari yang diasumsikan script ini."
        )
    return entry_source[idx:]


def main():
    if not os.path.isdir(SRC_DIR):
        raise SystemExit(f"Folder '{SRC_DIR}' nggak ketemu. Jalanin script ini dari root folder build/.")
    if not os.path.isfile(ENTRY_FILE):
        raise SystemExit(f"File '{ENTRY_FILE}' nggak ketemu.")

    modules = collect_modules(SRC_DIR)
    with open(ENTRY_FILE, "r", encoding="utf-8") as f:
        entry_source = f.read()

    body = strip_entry_bootstrap(entry_source)

    output = []
    output.append(build_modules_block(modules))
    output.append(build_import_shim())
    output.append(body)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(output))

    print(f"OK -> {OUT_FILE} ({len(modules)} modules digabung jadi 1 file)")


if __name__ == "__main__":
    main()