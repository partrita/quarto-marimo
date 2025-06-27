--[[
-- 참고: 이것은 순수 pandoc 필터이지만 quarto 프로젝트에서 사용됩니다.
-- 이상적으로는 유연성을 유지하기 위해 quarto 특정 사항에 의존하지 마십시오.
--]]

local utils = require("utils")

-- 전역 변수
local is_mime_sensitive = utils.is_mime_sensitive()
local missingMarimoCell = true
-- 메타와 동시에 추출 (샌드박싱의 경우)
local marimo_execution = nil
-- marimo_execution["outputs"]의 항목 수 계산
local expected_cells = nil
-- 현재 파싱된 블록의 수
local cell_index = 1

local initialize = {
    Meta = function(m)
        marimo_execution = utils.run_marimo(m)
        expected_cells = marimo_execution["count"]
        return m
    end,
}

local extract = {
    CodeBlock = function(el)
        --[[
        -- 예상 출력을 파싱된 코드 블록 위치와 일치시킵니다.
        --]]
        if
            el.attr
            and el.attr.classes:find_if(function(c)
                return string.match(c, ".*marimo.*")
            end)
        then
            missingMarimoCell = false
            if cell_index > expected_cells then
                message = string.format(
                    "예상보다 많은 셀을 추출하려고 시도했습니다. "
                        .. "%d (예상: %d)\n",
                    cell_index,
                    expected_cells
                )
                if pandoc.log ~= nil then
                    pandoc.log.warn(message)
                else
                    io.stderr:write(message)
                end
                cell_index = cell_index + 1
                return
            end
            cell_table = marimo_execution["outputs"][cell_index]
            cell_index = cell_index + 1

            -- 출력 유형이 MIME에 민감한 경우 (예: pdf 또는 latex) 유형이 반환됩니다.
            if is_mime_sensitive then
                local response = {} -- 비어 있음
                if cell_table.display_code then
                    table.insert(
                        response,
                        pandoc.CodeBlock(cell_table.code, "python")
                    )
                end

                if cell_table.type == "figure" then
                    -- latex/pdf의 경우 --extract-media=media 플래그와 함께 실행해야 합니다.
                    -- qmd 헤더에서도 설정할 수 있습니다.
                    image = pandoc.Image("Generated Figure", cell_table.value) -- 생성된 그림
                    table.insert(
                        response,
                        pandoc.Figure(pandoc.Para({ image }))
                    )
                    return response
                end
                if cell_table.type == "para" then
                    table.insert(response, pandoc.Para(cell_table.value))
                    return response
                end
                if cell_table.type == "blockquote" then
                    table.insert(response, pandoc.BlockQuote(cell_table.value))
                    return response
                end
                local code_block = response[1]
                response =
                    pandoc.read(cell_table.value, cell_table.type).blocks
                table.insert(response, code_block)
                return response
            end

            -- 응답은 HTML이므로 해당 형식과 호환되는 모든 형식이 괜찮습니다.
            return pandoc.RawBlock(cell_table.type, cell_table.value)
        end
    end,

    Pandoc = function(doc)
        --[[
        -- 헤더를 추가하고 최종 유효성 검사를 수행합니다.
        --]]

        -- 예상 개수와 실제 개수가 다르면 문제가 있는 것이므로 실패해야 합니다.
        if expected_cells ~= cell_index - 1 then
            error(
                "marimo 필터가 실패했습니다. 예상 셀 수: "
                    .. expected_cells
                    .. ", 실제 셀 수: "
                    .. cell_index - 1
            )
        end

        -- 필요하지 않으면 아무것도 하지 않습니다.
        if missingMarimoCell then
            return doc
        end

        if quarto == nil then
            message = (
                "quarto를 사용하지 않으므로 html 문서의 경우 문서 헤더에 다음을 포함해야 합니다:\n"
                .. marimo_execution["header"]
            )
            if pandoc.log ~= nil then
                pandoc.log.warn(message)
            else
                io.stderr:write(message)
            end
            return doc
        end

        -- html이 아닌 문서에는 에셋을 추가하지 않습니다.
        if not quarto.doc.is_format("html") then
            return doc
        end

        -- 로컬 테스트를 위해 프론트엔드 웹 서버에 연결할 수 있습니다.
        local dev_server = os.getenv("QUARTO_MARIMO_DEBUG_ENDPOINT")
        if dev_server ~= nil then
            quarto.doc.include_text(
                "in-header",
                '<meta name="referrer" content="unsafe-url" />'
                    .. '<script type="module" crossorigin="anonymous">import { injectIntoGlobalHook } from "'
                    .. dev_server
                    .. '/@react-refresh";injectIntoGlobalHook(window); window.$RefreshReg$ = () => {};'
                    .. "window.$RefreshSig$ = () => (type) => type;</script>"
                    .. '<script type="module" crossorigin="anonymous" src="'
                    .. dev_server
                    .. '/@vite/client"></script>'
            )
        end

        -- 웹 에셋, 가장 좋은 방법인 것 같습니다.
        quarto.doc.include_text("in-header", marimo_execution["header"])
        return doc
    end,
}

function Pandoc(doc)
    --[[
    -- Pandoc은 파싱 순서가 이상한 것 같습니다.
    -- (예: 블록은 메타보다 먼저, 메타는 판독보다 먼저 처리됨)
    -- 따라서 원하는 순서와 일치하도록 문서를 탐색합니다.
    --]]
    doc = doc:walk(initialize)
    doc = doc:walk(extract)
    return doc
end
