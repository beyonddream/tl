local tl = require("tl")
local util = require("spec.util")

describe("typecheck errors", function()
   it("type errors include filename", function ()
      local tokens = tl.lex("local x: string = 1")
      local _, ast = tl.parse_program(tokens, {})
      local errors, unknowns = tl.type_check(ast, false, "foo.tl")
      assert.same("foo.tl", errors[1].filename, "type errors should contain .filename property")
   end)

   it("type errors in a required package include filename of required file", function ()
      local tokens = tl.lex([[
         local bar = require "bar"
      ]])
      util.mock_io(finally, {
         ["bar.tl"] = "local x: string = 1",
      })
      local _, ast = tl.parse_program(tokens, {}, "foo.tl")
      local errors, unknowns = tl.type_check(ast, true, "foo.tl")
      assert.is_not_nil(string.match(errors[1].filename, "bar.tl$"), "type errors should contain .filename property")
   end)

   it("syntax errors in a nested required package refer to the correct filename of required file", function ()
      util.mock_io(finally, {
         ["aaa.tl"] = [[
            local bbb = require "bbb"

            function function() end

            local x: string = 1
         ]],
         ["bbb.tl"] = [[
            local bbb = {}

            bbb.y = 2

            if bbb.y end

            return bbb
         ]],
         ["foo.tl"] = [[
            local aaa = require "aaa"
         ]],
      })
      local result, err = tl.process("foo.tl")

      local expected = {
         { filename = "aaa.tl", y = 3 },
         { filename = "bbb.tl", y = 5 },
         { filename = "bbb.tl", y = 7 },
      }
      assert.same(#expected, #result.syntax_errors)
      for i, err in ipairs(result.syntax_errors) do
         assert.match(expected[i].filename, result.syntax_errors[i].filename, 1, true)
         assert.same(expected[i].y, result.syntax_errors[i].y)
      end
   end)

   it("unknowns include filename", function ()
      local tokens = tl.lex("local x: string = b")
      local _, ast = tl.parse_program(tokens, {})
      local errors, unknowns = tl.type_check(ast, true, "foo.tl")
      assert.same("foo.tl", unknowns[1].filename, "unknowns should contain .filename property")
   end)

   it("unknowns in a required package include filename of required file", function ()
      local tokens = tl.lex([[
         local bar = require "bar"
      ]])
      util.mock_io(finally, {
         ["bar.tl"] = "local x: string = b"
      })
      local _, ast = tl.parse_program(tokens, {}, "foo.tl")
      local errors, unknowns = tl.type_check(ast, true, "foo.tl")
      assert.is_not_nil(string.match(errors[1].filename, "bar.tl$"), "unknowns should contain .filename property")
   end)
end)
