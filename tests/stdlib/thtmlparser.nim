discard """
  output: '''
@[]
true
'''
"""
import htmlparser
import xmltree
import strutils
from streams import newStringStream


block t2813:
  const
    html = """
    <html>
      <head>
        <title>Test</title>
      </head>
      <body>
        <table>
          <thead>
            <tr><td>A</td></tr>
            <tr><td>B</td></tr>
          </thead>
          <tbody>
            <tr><td></td>A<td></td></tr>
            <tr><td></td>B<td></td></tr>
            <tr><td></td>C<td></td></tr>
          </tbody>
          <tfoot>
            <tr><td>A</td></tr>
          </tfoot>
        </table>
      </body>
    </html>
    """
  var errors: seq[string] = @[]
  let tree = parseHtml(newStringStream(html), "test.html", errors)
  echo errors # Errors: </thead> expected,...

  var len = tree.findAll("tr").len # len = 6
  var rows: seq[XmlNode] = @[]
  for n in tree.findAll("table"):
    n.findAll("tr", rows)  # len = 2
    break
  assert tree.findAll("tr").len == rows.len


block t2814:
  ## builds the two cases below and test that
  ## ``//[dd,li]`` has "<p>that</p>" as children
  ##
  ##  <dl>
  ##    <dt>this</dt>
  ##    <dd>
  ##      <p>that</p>
  ##    </dd>
  ##  </dl>

  ##
  ## <ul>
  ##   <li>
  ##     <p>that</p>
  ##   </li>
  ## </ul>
  for ltype in [["dl","dd"], ["ul","li"]]:
    let desc_item = if ltype[0]=="dl": "<dt>this</dt>" else: ""
    let item = "$1<$2><p>that</p></$2>" % [desc_item, ltype[1]]
    let list = """ <$1>
     $2
  </$1> """ % [ltype[0], item]

    var errors : seq[string] = @[]
    let parseH = parseHtml(newStringStream(list),"statichtml", errors =errors)

    if $parseH.findAll(ltype[1])[0].child("p") != "<p>that</p>":
      echo "case " & ltype[0] & " failed !"
      quit(2)
  echo "true"

block t6154:
  let foo = """
  <!DOCTYPE html>
  <html>
      <head>
        <title> foobar </title>
      </head>
      <body>
        <p class=foo id=bar></p>
        <p something=&#9;foo&#9;bar&#178;></p>
        <p something=  &#9;foo&#9;bar&#178; foo  =bloo></p>
        <p class="foo2" id="bar2"></p>
        <p wrong= ></p>
      </body>
  </html>
  """

  var errors: seq[string] = @[]
  let html = parseHtml(newStringStream(foo), "statichtml", errors=errors)
  doAssert "statichtml(11, 18) Error: attribute value expected" in errors
  let ps = html.findAll("p")
  doAssert ps.len == 5

  doAssert ps[0].attrsLen == 2
  doAssert ps[0].attr("class") == "foo"
  doAssert ps[0].attr("id") == "bar"
  doassert ps[0].len == 0

  doAssert ps[1].attrsLen == 1
  doAssert ps[1].attr("something") == "\tfoo\tbar²"
  doassert ps[1].len == 0

  doAssert ps[2].attrsLen == 2
  doAssert ps[2].attr("something") == "\tfoo\tbar²"
  doAssert ps[2].attr("foo") == "bloo"
  doassert ps[2].len == 0

  doAssert ps[3].attrsLen == 2
  doAssert ps[3].attr("class") == "foo2"
  doAssert ps[3].attr("id") == "bar2"
  doassert ps[3].len == 0

  doAssert ps[4].attrsLen == 1
  doAssert ps[4].attr("wrong") == ""
