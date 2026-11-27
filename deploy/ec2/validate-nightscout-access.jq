def names: map(.name) | length == (unique | length);
def name: type == "string" and test("^[a-zA-Z0-9_-]+$");
def strings: type == "array" and length > 0
  and all(.[]; type == "string" and length > 0)
  and length == (unique | length);
if type == "object" and (keys == ["roles", "subjects"])
  and (.roles | type == "array" and names)
  and (.subjects | type == "array" and names)
  and all(.roles[];
    keys == ["name", "permissions"] and (.name | name)
    and (.permissions | strings)
    and all(.permissions[]; test("^api:[a-z]+:(read|create|update)$")))
  and all(.subjects[];
    keys == ["name", "roles"] and (.name | name) and (.roles | strings))
then . else error("Invalid Nightscout access configuration") end
