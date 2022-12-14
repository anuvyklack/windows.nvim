local test_layouts = {}

-- ┌──────┬──────┬──────┬──────┐
-- │      │      │ 1005 │ 1007 │
-- │      │ 1003 ├──────┴──────┤
-- │ 1000 │      │    1006     │
-- │      ├──────┴─────────────┤
-- │      │        1004        │
-- └──────┴────────────────────┘
test_layouts[1] = { "row", {
   { "leaf", 1000 },
   { "col", {
      { "row", {
         { "leaf", 1003 },
         { "col", {
            { "row", {
               { "leaf", 1005 },
               { "leaf", 1007 }
            } },
            { "leaf", 1006 }
         } }
      } },
      { "leaf", 1004 }
   } }
} }

-- ┌──────┬──────┬──────────┬─────────┬──────┐
-- │ 1000 │ 1006 │   1003   │   1009  │      │
-- │      │      ├──────┬───┴──┬──────┤      │
-- ├──────┴──────┤ 1007 │ 1010 │ 1011 │ 1004 │
-- │             ├──────┴──────┴──────┤      │
-- │    1005     │        1008        │      │
-- └─────────────┴────────────────────┴──────┘
test_layouts[2] = { "row", {
   { "col", {
      { "row", {
         { "leaf", 1000 },
         { "leaf", 1006 }
      } },
      { "leaf", 1005 }
   } },
   { "col", {
      { "row", {
         { "leaf", 1003 },
         { "leaf", 1009 }
      } },
      { "row", {
         { "leaf", 1007 },
         { "leaf", 1010 },
         { "leaf", 1011 }
      } },
      { "leaf", 1008 }
   } },
   { "leaf", 1004 }
} }


return test_layouts
