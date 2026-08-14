std = "min"
max_line_length = 110
include_files = { "src", "spec", "bin", "*.rockspec", ".busted", ".luacheckrc" }
exclude_files = { "spec/fixtures", ".luarocks", "build" }

globals = { "arg" }
self = false -- widget/mock stubs frequently ignore their receiver
ignore = { "431" } -- shadowing an upvalue is idiomatic in the mock method definitions
read_globals = {
  "debug", "io", "os", "package", "require", "loadstring", "setfenv", "getfenv",
  "table", "string", "math", "coroutine", "bit", "bit32", "jit", "unpack", "_G",
}

files["spec"] = {
  std = "+busted",
}
files[".busted"] = { ignore = { "111", "112", "113" } }
files["*.rockspec"] = { globals = { "package" }, ignore = { "111", "112", "113", "122" } }
files["bin"] = { globals = { "package" } }
