-- utils
function is_mime_sensitive()
    -- Determine whether we can render the html tags that island produces. If
    -- not, this flag will let's us directly output a representative value.
    local output_file = PANDOC_STATE.output_file
    return string.match(output_file, "%.pdf$")
        or string.match(output_file, "%.tex$")
end
local stringify = pandoc.utils.stringify

-- Deduplicate and normalize sandbox dependencies,
-- always include marimo@version and any feature‑specific packages.
local function _normalize_sandbox_dependencies(deps, version, features)
    local seen, out = {}, {}
    for _, d in ipairs(deps or {}) do
        if not seen[d] then
            seen[d] = true
            table.insert(out, d)
        end
    end
    local marimo_dep = "marimo==" .. version
    if not seen[marimo_dep] then
        table.insert(out, marimo_dep)
        seen[marimo_dep] = true
    end
    for _, feat in ipairs(features or {}) do
        local fdep = "marimo-" .. tostring(feat) .. "==" .. version
        if not seen[fdep] then
            table.insert(out, fdep)
            seen[fdep] = true
        end
    end
    return out
end

-- Construct the full UV command given:
-- args               = list of marimo CLI args
-- additional_features= list of feature names
-- additional_deps    = list of extra pip deps
function _construct_uv_command(meta)
    -- print out all of meta
    for k, v in pairs(meta) do
        print(k)
    end

    -- 1. Build marimo invocation and strip "--sandbox"
    local cmd = { "marimo" }

    -- 2. Read metadata fields
    local version = stringify(
        meta["marimo-version"] or error("`marimo-version` missing in metadata")
    )
    local raw_deps = {}
    if meta.dependencies then
        for _, item in ipairs(meta.dependencies) do
            table.insert(raw_deps, stringify(item))
        end
    end
    local uv_needs_refresh = (#raw_deps == 0)

    local python_version = meta["requires-python"]
        and stringify(meta["requires-python"])

    local index_url = meta["index-url"] and stringify(meta["index-url"])

    local extra_index_urls = {}
    if meta["extra-index-urls"] then
        for _, item in ipairs(meta["extra-index-urls"]) do
            table.insert(extra_index_urls, stringify(item))
        end
    end

    local index_configs = {}
    if meta["index-configs"] then
        for _, cfg in ipairs(meta["index-configs"]) do
            local url = cfg.url and stringify(cfg.url)
            if url then
                table.insert(index_configs, { url = url })
            end
        end
    end

    -- 3. Normalize and extend dependencies
    local deps =
        _normalize_sandbox_dependencies(raw_deps, version, additional_features)
    for _, d in ipairs(additional_deps or {}) do
        table.insert(deps, d)
    end

    -- 4. Write deps to a temp requirements file
    local req_file = os.tmpname() .. ".txt"
    do
        local f = assert(io.open(req_file, "w"))
        f:write(table.concat(deps, "\n"))
        f:close()
    end
    -- Cleanup of req_file can be arranged at process exit

    -- 5. Build the UV command
    local uv_cmd = {
        "uv",
        "run",
        "--isolated",
        "--no-project",
        "--compile-bytecode",
        "--with-requirements",
        req_file,
    }
    if uv_needs_refresh then
        table.insert(uv_cmd, "--refresh")
    end
    if python_version then
        table.insert(uv_cmd, "--python")
        table.insert(uv_cmd, python_version)
    end
    if index_url then
        table.insert(uv_cmd, "--index-url")
        table.insert(uv_cmd, index_url)
    end
    for _, url in ipairs(extra_index_urls) do
        table.insert(uv_cmd, "--extra-index-url")
        table.insert(uv_cmd, url)
    end
    for _, cfg in ipairs(index_configs) do
        table.insert(uv_cmd, "--index")
        table.insert(uv_cmd, cfg.url)
    end

    -- 6. Append original marimo args and return
    for _, v in ipairs(cmd) do
        table.insert(uv_cmd, v)
    end

    return uv_cmd
end

function run_marimo(meta)
    -- if not meta["marimo-version"] then
    --     error("`marimo-version` missing in metadata")
    -- end
    -- local command = _construct_uv_command(meta)
    local file_path = debug.getinfo(1, "S").source:sub(2)
    local file_dir = file_path:match("(.*[/\\])")
    local endpoint_script = file_dir .. "extract.py"

    -- PDFs / LaTeX have to be handled specifically for mimetypes
    -- Need to pass in a string as arg in python invocation.
    local mime_sensitive = "no"
    if is_mime_sensitive(doc) then
        mime_sensitive = "yes"
    end

    local parsed_data = {}
    local result = {}
    for _, filename in ipairs(PANDOC_STATE.input_files) do
        local input_file = io.open(filename, "r")
        if input_file then
            local text = input_file:read("*all")
            input_file:close()

            text = text or ""

            -- Parse the input file using the external Python script
            result = pandoc.json.decode(
                pandoc.pipe(
                    endpoint_script,
                    { filename, mime_sensitive },
                    text
                )
            )
            -- Concatenate the result arrays
            for _, item in ipairs(result["outputs"]) do
                table.insert(parsed_data, item)
            end
        end
    end
    result["outputs"] = parsed_data
    return result
end

return {
    is_mime_sensitive = is_mime_sensitive,
    run_marimo = run_marimo,
}
