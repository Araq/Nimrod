import compiler/unittest_light

proc test_assertEquals() =
  assertEquals("foo", "foo")
  doAssertRaises(AssertionError):
    assertEquals("foo", "foo ")

proc test_mismatch() =
  assertEquals(1+1, 2*1)

  let a = """
  some test with space at the end of lines    

  can be hard to spot differences when diffing in a terminal   
  without this helper function

"""

  let b = """
  some test with space at the end of lines    

  can be hard to spot differences when diffing in a terminal  
  without this helper function

"""

  doAssert mismatch(a, b) == """

lhs:{
  some test with space at the end of lines    \n
\n
  can be hard to spot differences when diffing in a terminal   \n
  without this helper function\n
\n
}
rhs:{
  some test with space at the end of lines    \n
\n
  can be hard to spot differences when diffing in a terminal  \n
  without this helper function\n
\n
}
lhs.len: 144 rhs.len: 143
first mismatch index: 110
lhs[i]: {" "} rhs[i]: {"\n"}lhs[0..<i]:{
  some test with space at the end of lines    \n
\n
  can be hard to spot differences when diffing in a terminal  }
rhs[0..<i]:{
  some test with space at the end of lines    \n
\n
  can be hard to spot differences when diffing in a terminal  }"""

test_mismatch()
test_assertEquals()
