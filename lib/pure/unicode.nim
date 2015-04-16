#
#
#            Nim's Runtime Library
#        (c) Copyright 2015 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module provides support to handle the Unicode UTF-8 encoding.

{.deadCodeElim: on.}

include "system/inclrtl"

type
  RuneImpl = int # underlying type of Rune
  Rune* = distinct RuneImpl   ## type that can hold any Unicode character
  Rune16* = distinct int16 ## 16 bit Unicode character

{.deprecated: [TRune: Rune, TRune16: Rune16].}

proc `<=%`*(a, b: Rune): bool = return int(a) <=% int(b)
proc `<%`*(a, b: Rune): bool = return int(a) <% int(b)
proc `==`*(a, b: Rune): bool = return int(a) == int(b)

template ones(n: expr): expr = ((1 shl n)-1)

proc runeLen*(s: string): int {.rtl, extern: "nuc$1".} =
  ## returns the number of Unicode characters of the string `s`.
  var i = 0
  while i < len(s):
    if ord(s[i]) <=% 127: inc(i)
    elif ord(s[i]) shr 5 == 0b110: inc(i, 2)
    elif ord(s[i]) shr 4 == 0b1110: inc(i, 3)
    elif ord(s[i]) shr 3 == 0b11110: inc(i, 4)
    elif ord(s[i]) shr 2 == 0b111110: inc(i, 5)
    elif ord(s[i]) shr 1 == 0b1111110: inc(i, 6)
    else: inc i
    inc(result)

proc runeLenAt*(s: string, i: Natural): int =
  ## returns the number of bytes the rune starting at ``s[i]`` takes.
  if ord(s[i]) <=% 127: result = 1
  elif ord(s[i]) shr 5 == 0b110: result = 2
  elif ord(s[i]) shr 4 == 0b1110: result = 3
  elif ord(s[i]) shr 3 == 0b11110: result = 4
  elif ord(s[i]) shr 2 == 0b111110: result = 5
  elif ord(s[i]) shr 1 == 0b1111110: result = 6
  else: result = 1

template fastRuneAt*(s: string, i: int, result: expr, doInc = true) =
  ## Returns the unicode character ``s[i]`` in `result`. If ``doInc == true``
  ## `i` is incremented by the number of bytes that have been processed.
  bind ones
  if ord(s[i]) <=% 127:
    result = Rune(ord(s[i]))
    when doInc: inc(i)
  elif ord(s[i]) shr 5 == 0b110:
    # assert(ord(s[i+1]) shr 6 == 0b10)
    result = Rune((ord(s[i]) and (ones(5))) shl 6 or
                  (ord(s[i+1]) and ones(6)))
    when doInc: inc(i, 2)
  elif ord(s[i]) shr 4 == 0b1110:
    # assert(ord(s[i+1]) shr 6 == 0b10)
    # assert(ord(s[i+2]) shr 6 == 0b10)
    result = Rune((ord(s[i]) and ones(4)) shl 12 or
             (ord(s[i+1]) and ones(6)) shl 6 or
             (ord(s[i+2]) and ones(6)))
    when doInc: inc(i, 3)
  elif ord(s[i]) shr 3 == 0b11110:
    # assert(ord(s[i+1]) shr 6 == 0b10)
    # assert(ord(s[i+2]) shr 6 == 0b10)
    # assert(ord(s[i+3]) shr 6 == 0b10)
    result = Rune((ord(s[i]) and ones(3)) shl 18 or
             (ord(s[i+1]) and ones(6)) shl 12 or
             (ord(s[i+2]) and ones(6)) shl 6 or
             (ord(s[i+3]) and ones(6)))
    when doInc: inc(i, 4)
  elif ord(s[i]) shr 2 == 0b111110:
    # assert(ord(s[i+1]) shr 6 == 0b10)
    # assert(ord(s[i+2]) shr 6 == 0b10)
    # assert(ord(s[i+3]) shr 6 == 0b10)
    # assert(ord(s[i+4]) shr 6 == 0b10)
    result = Rune((ord(s[i]) and ones(2)) shl 24 or
             (ord(s[i+1]) and ones(6)) shl 18 or
             (ord(s[i+2]) and ones(6)) shl 12 or
             (ord(s[i+3]) and ones(6)) shl 6 or
             (ord(s[i+4]) and ones(6)))
    when doInc: inc(i, 5)
  elif ord(s[i]) shr 1 == 0b1111110:
    # assert(ord(s[i+1]) shr 6 == 0b10)
    # assert(ord(s[i+2]) shr 6 == 0b10)
    # assert(ord(s[i+3]) shr 6 == 0b10)
    # assert(ord(s[i+4]) shr 6 == 0b10)
    # assert(ord(s[i+5]) shr 6 == 0b10)
    result = Rune((ord(s[i]) and ones(1)) shl 30 or
             (ord(s[i+1]) and ones(6)) shl 24 or
             (ord(s[i+2]) and ones(6)) shl 18 or
             (ord(s[i+3]) and ones(6)) shl 12 or
             (ord(s[i+4]) and ones(6)) shl 6 or
             (ord(s[i+5]) and ones(6)))
    when doInc: inc(i, 6)
  else:
    result = Rune(ord(s[i]))
    when doInc: inc(i)

proc runeAt*(s: string, i: Natural): Rune =
  ## returns the unicode character in `s` at byte index `i`
  fastRuneAt(s, i, result, false)

proc toUTF8*(c: Rune): string {.rtl, extern: "nuc$1".} =
  ## converts a rune into its UTF8 representation
  var i = RuneImpl(c)
  if i <=% 127:
    result = newString(1)
    result[0] = chr(i)
  elif i <=% 0x07FF:
    result = newString(2)
    result[0] = chr((i shr 6) or 0b110_00000)
    result[1] = chr((i and ones(6)) or 0b10_0000_00)
  elif i <=% 0xFFFF:
    result = newString(3)
    result[0] = chr(i shr 12 or 0b1110_0000)
    result[1] = chr(i shr 6 and ones(6) or 0b10_0000_00)
    result[2] = chr(i and ones(6) or 0b10_0000_00)
  elif i <=% 0x001FFFFF:
    result = newString(4)
    result[0] = chr(i shr 18 or 0b1111_0000)
    result[1] = chr(i shr 12 and ones(6) or 0b10_0000_00)
    result[2] = chr(i shr 6 and ones(6) or 0b10_0000_00)
    result[3] = chr(i and ones(6) or 0b10_0000_00)
  elif i <=% 0x03FFFFFF:
    result = newString(5)
    result[0] = chr(i shr 24 or 0b111110_00)
    result[1] = chr(i shr 18 and ones(6) or 0b10_0000_00)
    result[2] = chr(i shr 12 and ones(6) or 0b10_0000_00)
    result[3] = chr(i shr 6 and ones(6) or 0b10_0000_00)
    result[4] = chr(i and ones(6) or 0b10_0000_00)
  elif i <=% 0x7FFFFFFF:
    result = newString(6)
    result[0] = chr(i shr 30 or 0b1111110_0)
    result[1] = chr(i shr 24 and ones(6) or 0b10_0000_00)
    result[2] = chr(i shr 18 and ones(6) or 0b10_0000_00)
    result[3] = chr(i shr 12 and ones(6) or 0b10_0000_00)
    result[4] = chr(i shr 6 and ones(6) or 0b10_0000_00)
    result[5] = chr(i and ones(6) or 0b10_0000_00)
  else:
    discard # error, exception?

proc `$`*(rune: Rune): string =
  ## converts a rune to a string
  rune.toUTF8

proc `$`*(runes: seq[Rune]): string =
  ## converts a sequence of runes to a string
  result = ""
  for rune in runes: result.add(rune.toUTF8)

const
  alphaRanges = [
    0x00d8,  0x00f6,  #  -
    0x00f8,  0x01f5,  #  -
    0x0250,  0x02a8,  #  -
    0x038e,  0x03a1,  #  -
    0x03a3,  0x03ce,  #  -
    0x03d0,  0x03d6,  #  -
    0x03e2,  0x03f3,  #  -
    0x0490,  0x04c4,  #  -
    0x0561,  0x0587,  #  -
    0x05d0,  0x05ea,  #  -
    0x05f0,  0x05f2,  #  -
    0x0621,  0x063a,  #  -
    0x0640,  0x064a,  #  -
    0x0671,  0x06b7,  #  -
    0x06ba,  0x06be,  #  -
    0x06c0,  0x06ce,  #  -
    0x06d0,  0x06d3,  #  -
    0x0905,  0x0939,  #  -
    0x0958,  0x0961,  #  -
    0x0985,  0x098c,  #  -
    0x098f,  0x0990,  #  -
    0x0993,  0x09a8,  #  -
    0x09aa,  0x09b0,  #  -
    0x09b6,  0x09b9,  #  -
    0x09dc,  0x09dd,  #  -
    0x09df,  0x09e1,  #  -
    0x09f0,  0x09f1,  #  -
    0x0a05,  0x0a0a,  #  -
    0x0a0f,  0x0a10,  #  -
    0x0a13,  0x0a28,  #  -
    0x0a2a,  0x0a30,  #  -
    0x0a32,  0x0a33,  #  -
    0x0a35,  0x0a36,  #  -
    0x0a38,  0x0a39,  #  -
    0x0a59,  0x0a5c,  #  -
    0x0a85,  0x0a8b,  #  -
    0x0a8f,  0x0a91,  #  -
    0x0a93,  0x0aa8,  #  -
    0x0aaa,  0x0ab0,  #  -
    0x0ab2,  0x0ab3,  #  -
    0x0ab5,  0x0ab9,  #  -
    0x0b05,  0x0b0c,  #  -
    0x0b0f,  0x0b10,  #  -
    0x0b13,  0x0b28,  #  -
    0x0b2a,  0x0b30,  #  -
    0x0b32,  0x0b33,  #  -
    0x0b36,  0x0b39,  #  -
    0x0b5c,  0x0b5d,  #  -
    0x0b5f,  0x0b61,  #  -
    0x0b85,  0x0b8a,  #  -
    0x0b8e,  0x0b90,  #  -
    0x0b92,  0x0b95,  #  -
    0x0b99,  0x0b9a,  #  -
    0x0b9e,  0x0b9f,  #  -
    0x0ba3,  0x0ba4,  #  -
    0x0ba8,  0x0baa,  #  -
    0x0bae,  0x0bb5,  #  -
    0x0bb7,  0x0bb9,  #  -
    0x0c05,  0x0c0c,  #  -
    0x0c0e,  0x0c10,  #  -
    0x0c12,  0x0c28,  #  -
    0x0c2a,  0x0c33,  #  -
    0x0c35,  0x0c39,  #  -
    0x0c60,  0x0c61,  #  -
    0x0c85,  0x0c8c,  #  -
    0x0c8e,  0x0c90,  #  -
    0x0c92,  0x0ca8,  #  -
    0x0caa,  0x0cb3,  #  -
    0x0cb5,  0x0cb9,  #  -
    0x0ce0,  0x0ce1,  #  -
    0x0d05,  0x0d0c,  #  -
    0x0d0e,  0x0d10,  #  -
    0x0d12,  0x0d28,  #  -
    0x0d2a,  0x0d39,  #  -
    0x0d60,  0x0d61,  #  -
    0x0e01,  0x0e30,  #  -
    0x0e32,  0x0e33,  #  -
    0x0e40,  0x0e46,  #  -
    0x0e5a,  0x0e5b,  #  -
    0x0e81,  0x0e82,  #  -
    0x0e87,  0x0e88,  #  -
    0x0e94,  0x0e97,  #  -
    0x0e99,  0x0e9f,  #  -
    0x0ea1,  0x0ea3,  #  -
    0x0eaa,  0x0eab,  #  -
    0x0ead,  0x0eae,  #  -
    0x0eb2,  0x0eb3,  #  -
    0x0ec0,  0x0ec4,  #  -
    0x0edc,  0x0edd,  #  -
    0x0f18,  0x0f19,  #  -
    0x0f40,  0x0f47,  #  -
    0x0f49,  0x0f69,  #  -
    0x10d0,  0x10f6,  #  -
    0x1100,  0x1159,  #  -
    0x115f,  0x11a2,  #  -
    0x11a8,  0x11f9,  #  -
    0x1e00,  0x1e9b,  #  -
    0x1f50,  0x1f57,  #  -
    0x1f80,  0x1fb4,  #  -
    0x1fb6,  0x1fbc,  #  -
    0x1fc2,  0x1fc4,  #  -
    0x1fc6,  0x1fcc,  #  -
    0x1fd0,  0x1fd3,  #  -
    0x1fd6,  0x1fdb,  #  -
    0x1fe0,  0x1fec,  #  -
    0x1ff2,  0x1ff4,  #  -
    0x1ff6,  0x1ffc,  #  -
    0x210a,  0x2113,  #  -
    0x2115,  0x211d,  #  -
    0x2120,  0x2122,  #  -
    0x212a,  0x2131,  #  -
    0x2133,  0x2138,  #  -
    0x3041,  0x3094,  #  -
    0x30a1,  0x30fa,  #  -
    0x3105,  0x312c,  #  -
    0x3131,  0x318e,  #  -
    0x3192,  0x319f,  #  -
    0x3260,  0x327b,  #  -
    0x328a,  0x32b0,  #  -
    0x32d0,  0x32fe,  #  -
    0x3300,  0x3357,  #  -
    0x3371,  0x3376,  #  -
    0x337b,  0x3394,  #  -
    0x3399,  0x339e,  #  -
    0x33a9,  0x33ad,  #  -
    0x33b0,  0x33c1,  #  -
    0x33c3,  0x33c5,  #  -
    0x33c7,  0x33d7,  #  -
    0x33d9,  0x33dd,  #  -
    0x4e00,  0x9fff,  #  -
    0xac00,  0xd7a3,  #  -
    0xf900,  0xfb06,  #  -
    0xfb13,  0xfb17,  #  -
    0xfb1f,  0xfb28,  #  -
    0xfb2a,  0xfb36,  #  -
    0xfb38,  0xfb3c,  #  -
    0xfb40,  0xfb41,  #  -
    0xfb43,  0xfb44,  #  -
    0xfb46,  0xfbb1,  #  -
    0xfbd3,  0xfd3d,  #  -
    0xfd50,  0xfd8f,  #  -
    0xfd92,  0xfdc7,  #  -
    0xfdf0,  0xfdf9,  #  -
    0xfe70,  0xfe72,  #  -
    0xfe76,  0xfefc,  #  -
    0xff66,  0xff6f,  #  -
    0xff71,  0xff9d,  #  -
    0xffa0,  0xffbe,  #  -
    0xffc2,  0xffc7,  #  -
    0xffca,  0xffcf,  #  -
    0xffd2,  0xffd7,  #  -
    0xffda,  0xffdc]  #  -
  
  numRanges = [
    0x0030,  0x0039,  # digit zero..digit nine
    0x00b2,  0x00b3,  # superscript two..superscript three
    0x00bc,  0x00be,  # vulgar fraction one quarter..vulgar fraction three quarters]
    0x0660,  0x0669,  # arabic-indic digit zero..arabic-indic digit nine
    0x06f0,  0x06f9,  # extended arabic-indic digit zero..extended arabic-indic digit nine
    0x07c0,  0x07c9,  # nko digit zero..nko digit nine
    0x0966,  0x096f,  # devanagari digit zero..devanagari digit nine
    0x09e6,  0x09ef,  # bengali digit zero..bengali digit nine
    0x09f4,  0x09f9,  # bengali currency numerator one..bengali currency denominator sixteen
    0x0a66,  0x0a6f,  # gurmukhi digit zero..gurmukhi digit nine
    0x0ae6,  0x0aef,  # gujarati digit zero..gujarati digit nine
    0x0b66,  0x0b6f,  # oriya digit zero..oriya digit nine
    0x0b72,  0x0b77,  # oriya fraction one quarter..oriya fraction three sixteenths
    0x0be6,  0x0bef,  # tamil digit zero..tamil digit nine
    0x0bf0,  0x0bf2,  # tamil number ten..tamil number one thousand
    0x0c66,  0x0c6f,  # telugu digit zero..telugu digit nine
    0x0c78,  0x0c7e,  # telugu fraction digit zero for odd powers of four..telugu fraction digit three for even powers of four
    0x0ce6,  0x0cef,  # kannada digit zero..kannada digit nine
    0x0d66,  0x0d6f,  # malayalam digit zero..malayalam digit nine
    0x0d70,  0x0d75,  # malayalam number ten..malayalam fraction three quarters
    0x0de6,  0x0def,  # sinhala lith digit zero..sinhala lith digit nine
    0x0e50,  0x0e59,  # thai digit zero..thai digit nine
    0x0ed0,  0x0ed9,  # lao digit zero..lao digit nine
    0x0f20,  0x0f29,  # tibetan digit zero..tibetan digit nine
    0x0f2a,  0x0f33,  # tibetan digit half one..tibetan digit half zero
    0x1040,  0x1049,  # myanmar digit zero..myanmar digit nine
    0x1090,  0x1099,  # myanmar shan digit zero..myanmar shan digit nine
    0x1369,  0x1371,  # ethiopic digit one..ethiopic digit nine
    0x1372,  0x137c,  # ethiopic number ten..ethiopic number ten thousand
    0x16ee,  0x16f0,  # runic arlaug symbol..runic belgthor symbol
    0x17e0,  0x17e9,  # khmer digit zero..khmer digit nine
    0x17f0,  0x17f9,  # khmer symbol lek attak son..khmer symbol lek attak pram-buon
    0x1810,  0x1819,  # mongolian digit zero..mongolian digit nine
    0x1946,  0x194f,  # limbu digit zero..limbu digit nine
    0x19d0,  0x19d9,  # new tai lue digit zero..new tai lue digit nine
    0x1a80,  0x1a89,  # tai tham hora digit zero..tai tham hora digit nine
    0x1a90,  0x1a99,  # tai tham tham digit zero..tai tham tham digit nine
    0x1b50,  0x1b59,  # balinese digit zero..balinese digit nine
    0x1bb0,  0x1bb9,  # sundanese digit zero..sundanese digit nine
    0x1c40,  0x1c49,  # lepcha digit zero..lepcha digit nine
    0x1c50,  0x1c59,  # ol chiki digit zero..ol chiki digit nine
    0x2074,  0x2079,  # superscript four..superscript nine
    0x2080,  0x2089,  # subscript zero..subscript nine
    0x2150,  0x215f,  # vulgar fraction one seventh..fraction numerator one
    0x2160,  0x2182,  # roman numeral one..roman numeral ten thousand
    0x2185,  0x2188,  # roman numeral six late form..roman numeral one hundred thousand
    0x2460,  0x2468,  # circled digit one..circled digit nine
    0x2469,  0x2473,  # circled number ten..circled number twenty
    0x2474,  0x247c,  # parenthesized digit one..parenthesized digit nine
    0x247d,  0x2487,  # parenthesized number ten..parenthesized number twenty
    0x2488,  0x2490,  # digit one full stop..digit nine full stop
    0x2491,  0x249b,  # number ten full stop..number twenty full stop
    0x24eb,  0x24f4,  # negative circled number eleven..negative circled number twenty
    0x24f5,  0x24fd,  # double circled digit one..double circled digit nine
    0x2776,  0x277e,  # dingbat negative circled digit one..dingbat negative circled digit nine
    0x2780,  0x2788,  # dingbat circled sans-serif digit one..dingbat circled sans-serif digit nine
    0x278a,  0x2792,  # dingbat negative circled sans-serif digit one..dingbat negative circled sans-serif digit nine
    0x3021,  0x3029,  # hangzhou numeral one..hangzhou numeral nine
    0x3038,  0x303a,  # hangzhou numeral ten..hangzhou numeral thirty
    0x3192,  0x3195,  # ideographic annotation one mark..ideographic annotation four mark
    0x3220,  0x3229,  # parenthesized ideograph one..parenthesized ideograph ten
    0x3248,  0x324f,  # circled number ten on black square..circled number eighty on black square
    0x3251,  0x325f,  # circled number twenty one..circled number thirty five
    0x3280,  0x3289,  # circled ideograph one..circled ideograph ten
    0x32b1,  0x32bf,  # circled number thirty six..circled number fifty
    0x4ebf,  0x4ec0,  # cjk unified ideograph-4ebf..cjk unified ideograph-4ec0
    0x53c1,  0x53c4,  # cjk unified ideograph-53c1..cjk unified ideograph-53c4
    0x5efe,  0x5eff,  # cjk unified ideograph-5efe..cjk unified ideograph-5eff
    0x5f0c,  0x5f0e,  # cjk unified ideograph-5f0c..cjk unified ideograph-5f0e
    0xa620,  0xa629,  # vai digit zero..vai digit nine
    0xa6e6,  0xa6ef,  # bamum letter mo..bamum letter koghom
    0xa830,  0xa835,  # north indic fraction one quarter..north indic fraction three sixteenths
    0xa8d0,  0xa8d9,  # saurashtra digit zero..saurashtra digit nine
    0xa900,  0xa909,  # kayah li digit zero..kayah li digit nine
    0xa9d0,  0xa9d9,  # javanese digit zero..javanese digit nine
    0xa9f0,  0xa9f9,  # myanmar tai laing digit zero..myanmar tai laing digit nine
    0xaa50,  0xaa59,  # cham digit zero..cham digit nine
    0xabf0,  0xabf9,  # meetei mayek digit zero..meetei mayek digit nine
    0xff10,  0xff19,  # fullwidth digit zero..fullwidth digit nine
    0x10107,  0x10133,  # aegean number one..aegean number ninety thousand
    0x10140,  0x10174,  # greek acrophonic attic one quarter..greek acrophonic stratian fifty mnas
    0x10175,  0x10178,  # greek one half sign..greek three quarters sign
    0x1018a,  0x1018b,  # greek zero sign..greek one quarter sign
    0x102e1,  0x102fb,  # coptic epact digit one..coptic epact number nine hundred
    0x10320,  0x10323,  # old italic numeral one..old italic numeral fifty
    0x103d1,  0x103d5,  # old persian number one..old persian number hundred
    0x104a0,  0x104a9,  # osmanya digit zero..osmanya digit nine
    0x10858,  0x1085f,  # imperial aramaic number one..imperial aramaic number ten thousand
    0x10879,  0x1087f,  # palmyrene number one..palmyrene number twenty
    0x108a7,  0x108af,  # nabataean number one..nabataean number one hundred
    0x10916,  0x1091b,  # phoenician number one..phoenician number three
    0x10a40,  0x10a43,  # kharoshthi digit one..kharoshthi digit four
    0x10a44,  0x10a47,  # kharoshthi number ten..kharoshthi number one thousand
    0x10a7d,  0x10a7e,  # old south arabian number one..old south arabian number fifty
    0x10a9d,  0x10a9f,  # old north arabian number one..old north arabian number twenty
    0x10aeb,  0x10aef,  # manichaean number one..manichaean number one hundred
    0x10b58,  0x10b5f,  # inscriptional parthian number one..inscriptional parthian number one thousand
    0x10b78,  0x10b7f,  # inscriptional pahlavi number one..inscriptional pahlavi number one thousand
    0x10ba9,  0x10baf,  # psalter pahlavi number one..psalter pahlavi number one hundred
    0x10e60,  0x10e68,  # rumi digit one..rumi digit nine
    0x10e69,  0x10e7e,  # rumi number ten..rumi fraction two thirds
    0x11052,  0x1105a,  # brahmi number one..brahmi number nine
    0x1105b,  0x11065,  # brahmi number ten..brahmi number one thousand
    0x11066,  0x1106f,  # brahmi digit zero..brahmi digit nine
    0x110f0,  0x110f9,  # sora sompeng digit zero..sora sompeng digit nine
    0x11136,  0x1113f,  # chakma digit zero..chakma digit nine
    0x111d0,  0x111d9,  # sharada digit zero..sharada digit nine
    0x111e1,  0x111f4,  # sinhala archaic digit one..sinhala archaic number one thousand
    0x112f0,  0x112f9,  # khudawadi digit zero..khudawadi digit nine
    0x114d0,  0x114d9,  # tirhuta digit zero..tirhuta digit nine
    0x11650,  0x11659,  # modi digit zero..modi digit nine
    0x116c0,  0x116c9,  # takri digit zero..takri digit nine
    0x118e0,  0x118e9,  # warang citi digit zero..warang citi digit nine
    0x118ea,  0x118f2,  # warang citi number ten..warang citi number ninety
    0x12400,  0x1246e,  # cuneiform numeric sign two ash..cuneiform numeric sign nine u variant form
    0x16a60,  0x16a69,  # mro digit zero..mro digit nine
    0x16b50,  0x16b59,  # pahawh hmong digit zero..pahawh hmong digit nine
    0x16b5b,  0x16b61,  # pahawh hmong number tens..pahawh hmong number trillions
    0x1d360,  0x1d371,  # counting rod unit digit one..counting rod tens digit nine
    0x1d7ce,  0x1d7ff,  # mathematical bold digit zero..mathematical monospace digit nine
    0x1e8c7,  0x1e8cf,  # mende kikakui digit one..mende kikakui digit nine
    0x1f100,  0x1f10a,  # digit zero full stop..digit nine comma
    0x1f10b,  0x1f10c,  # dingbat circled sans-serif digit zero..dingbat negative circled sans-serif digit zero
  ]
  
  numSinglets = [
    0x00b9, # superscript one
    0x19da, # new tai lue tham digit one
    0x2070, # superscript zero
    0x2189, # vulgar fraction zero thirds
    0x24ea, # circled digit zero
    0x24fe, # double circled number ten
    0x24ff, # negative circled digit zero
    0x277f, # dingbat negative circled number ten
    0x2789, # dingbat circled sans-serif number ten
    0x2793, # dingbat negative circled sans-serif number ten
    0x2cfd, # coptic fraction one half
    0x3007, # ideographic number zero
    0x3405, # cjk unified ideograph-3405
    0x3483, # cjk unified ideograph-3483
    0x382a, # cjk unified ideograph-382a
    0x3b4d, # cjk unified ideograph-3b4d
    0x4e00, # cjk unified ideograph-4e00
    0x4e03, # cjk unified ideograph-4e03
    0x4e07, # cjk unified ideograph-4e07
    0x4e09, # cjk unified ideograph-4e09
    0x4e5d, # cjk unified ideograph-4e5d
    0x4e8c, # cjk unified ideograph-4e8c
    0x4e94, # cjk unified ideograph-4e94
    0x4e96, # cjk unified ideograph-4e96
    0x4edf, # cjk unified ideograph-4edf
    0x4ee8, # cjk unified ideograph-4ee8
    0x4f0d, # cjk unified ideograph-4f0d
    0x4f70, # cjk unified ideograph-4f70
    0x5104, # cjk unified ideograph-5104
    0x5146, # cjk unified ideograph-5146
    0x5169, # cjk unified ideograph-5169
    0x516b, # cjk unified ideograph-516b
    0x516d, # cjk unified ideograph-516d
    0x5341, # cjk unified ideograph-5341
    0x534c, # cjk unified ideograph-534c
    0x56db, # cjk unified ideograph-56db
    0x58f1, # cjk unified ideograph-58f1
    0x58f9, # cjk unified ideograph-58f9
    0x5e7a, # cjk unified ideograph-5e7a
    0x5f10, # cjk unified ideograph-5f10
    0x62fe, # cjk unified ideograph-62fe
    0x634c, # cjk unified ideograph-634c
    0x67d2, # cjk unified ideograph-67d2
    0x6f06, # cjk unified ideograph-6f06
    0x7396, # cjk unified ideograph-7396
    0x767e, # cjk unified ideograph-767e
    0x8086, # cjk unified ideograph-8086
    0x842c, # cjk unified ideograph-842c
    0x8cae, # cjk unified ideograph-8cae
    0x8cb3, # cjk unified ideograph-8cb3
    0x8d30, # cjk unified ideograph-8d30
    0x9621, # cjk unified ideograph-9621
    0x9646, # cjk unified ideograph-9646
    0x964c, # cjk unified ideograph-964c
    0x9678, # cjk unified ideograph-9678
    0x96f6, # cjk unified ideograph-96f6
    0xf96b, # cjk compatibility ideograph-f96b
    0xf973, # cjk compatibility ideograph-f973
    0xf978, # cjk compatibility ideograph-f978
    0xf9b2, # cjk compatibility ideograph-f9b2
    0xf9d1, # cjk compatibility ideograph-f9d1
    0xf9d3, # cjk compatibility ideograph-f9d3
    0xf9fd, # cjk compatibility ideograph-f9fd
    0x10341, # gothic letter ninety
    0x1034a, # gothic letter nine hundred
    0x20001, # cjk unified ideograph-20001
    0x20064, # cjk unified ideograph-20064
    0x200e2, # cjk unified ideograph-200e2
    0x200e2, # cjk unified ideograph-200e2
    0x20121, # cjk unified ideograph-20121
    0x2092a, # cjk unified ideograph-2092a
    0x20983, # cjk unified ideograph-20983
    0x2098c, # cjk unified ideograph-2098c
    0x2099c, # cjk unified ideograph-2099c
    0x20aea, # cjk unified ideograph-20aea
    0x20afd, # cjk unified ideograph-20afd
    0x20b19, # cjk unified ideograph-20b19
    0x22390, # cjk unified ideograph-22390
    0x22998, # cjk unified ideograph-22998
    0x23b1b, # cjk unified ideograph-23b1b
    0x2626d, # cjk unified ideograph-2626d
    0x2f890, # cjk compatibility ideograph-2f890
  ]

  alphaSinglets = [
    0x00aa,  #
    0x00b5,  #
    0x00ba,  #
    0x03da,  #
    0x03dc,  #
    0x03de,  #
    0x03e0,  #
    0x06d5,  #
    0x09b2,  #
    0x0a5e,  #
    0x0a8d,  #
    0x0ae0,  #
    0x0b9c,  #
    0x0cde,  #
    0x0e4f,  #
    0x0e84,  #
    0x0e8a,  #
    0x0e8d,  #
    0x0ea5,  #
    0x0ea7,  #
    0x0eb0,  #
    0x0ebd,  #
    0x1fbe,  #
    0x207f,  #
    0x20a8,  #
    0x2102,  #
    0x2107,  #
    0x2124,  #
    0x2126,  #
    0x2128,  #
    0xfb3e,  #
    0xfe74]  #

  spaceRanges = [
    0x0009,  0x000a,  # tab and newline
    0x0020,  0x0020,  # space
    0x00a0,  0x00a0,  #
    0x2000,  0x200b,  #  -
    0x2028,  0x2029,  #  -     0x3000,  0x3000,  #
    0xfeff,  0xfeff]  #

  toupperRanges = [
    0x0061,  0x007a, 468,  # a-z A-Z
    0x00e0,  0x00f6, 468,  # - -
    0x00f8,  0x00fe, 468,  # - -
    0x0256,  0x0257, 295,  # - -
    0x0258,  0x0259, 298,  # - -
    0x028a,  0x028b, 283,  # - -
    0x03ad,  0x03af, 463,  # - -
    0x03b1,  0x03c1, 468,  # - -
    0x03c3,  0x03cb, 468,  # - -
    0x03cd,  0x03ce, 437,  # - -
    0x0430,  0x044f, 468,  # - -
    0x0451,  0x045c, 420,  # - -
    0x045e,  0x045f, 420,  # - -
    0x0561,  0x0586, 452,  # - -
    0x1f00,  0x1f07, 508,  # - -
    0x1f10,  0x1f15, 508,  # - -
    0x1f20,  0x1f27, 508,  # - -
    0x1f30,  0x1f37, 508,  # - -
    0x1f40,  0x1f45, 508,  # - -
    0x1f60,  0x1f67, 508,  # - -
    0x1f70,  0x1f71, 574,  # - -
    0x1f72,  0x1f75, 586,  # - -
    0x1f76,  0x1f77, 600,  # - -
    0x1f78,  0x1f79, 628,  # - -
    0x1f7a,  0x1f7b, 612,  # - -
    0x1f7c,  0x1f7d, 626,  # - -
    0x1f80,  0x1f87, 508,  # - -
    0x1f90,  0x1f97, 508,  # - -
    0x1fa0,  0x1fa7, 508,  # - -
    0x1fb0,  0x1fb1, 508,  # - -
    0x1fd0,  0x1fd1, 508,  # - -
    0x1fe0,  0x1fe1, 508,  # - -
    0x2170,  0x217f, 484,  # - -
    0x24d0,  0x24e9, 474,  # - -
    0xff41,  0xff5a, 468]  # - -

  toupperSinglets = [
    0x00ff, 621,  #
    0x0101, 499,  #
    0x0103, 499,  #
    0x0105, 499,  #
    0x0107, 499,  #
    0x0109, 499,  #
    0x010b, 499,  #
    0x010d, 499,  #
    0x010f, 499,  #
    0x0111, 499,  #
    0x0113, 499,  #
    0x0115, 499,  #
    0x0117, 499,  #
    0x0119, 499,  #
    0x011b, 499,  #
    0x011d, 499,  #
    0x011f, 499,  #
    0x0121, 499,  #
    0x0123, 499,  #
    0x0125, 499,  #
    0x0127, 499,  #
    0x0129, 499,  #
    0x012b, 499,  #
    0x012d, 499,  #
    0x012f, 499,  #
    0x0131, 268,  #  I
    0x0133, 499,  #
    0x0135, 499,  #
    0x0137, 499,  #
    0x013a, 499,  #
    0x013c, 499,  #
    0x013e, 499,  #
    0x0140, 499,  #
    0x0142, 499,  #
    0x0144, 499,  #
    0x0146, 499,  #
    0x0148, 499,  #
    0x014b, 499,  #
    0x014d, 499,  #
    0x014f, 499,  #
    0x0151, 499,  #
    0x0153, 499,  #
    0x0155, 499,  #
    0x0157, 499,  #
    0x0159, 499,  #
    0x015b, 499,  #
    0x015d, 499,  #
    0x015f, 499,  #
    0x0161, 499,  #
    0x0163, 499,  #
    0x0165, 499,  #
    0x0167, 499,  #
    0x0169, 499,  #
    0x016b, 499,  #
    0x016d, 499,  #
    0x016f, 499,  #
    0x0171, 499,  #
    0x0173, 499,  #
    0x0175, 499,  #
    0x0177, 499,  #
    0x017a, 499,  #
    0x017c, 499,  #
    0x017e, 499,  #
    0x017f, 200,  #  S
    0x0183, 499,  #
    0x0185, 499,  #
    0x0188, 499,  #
    0x018c, 499,  #
    0x0192, 499,  #
    0x0199, 499,  #
    0x01a1, 499,  #
    0x01a3, 499,  #
    0x01a5, 499,  #
    0x01a8, 499,  #
    0x01ad, 499,  #
    0x01b0, 499,  #
    0x01b4, 499,  #
    0x01b6, 499,  #
    0x01b9, 499,  #
    0x01bd, 499,  #
    0x01c5, 499,  #
    0x01c6, 498,  #
    0x01c8, 499,  #
    0x01c9, 498,  #
    0x01cb, 499,  #
    0x01cc, 498,  #
    0x01ce, 499,  #
    0x01d0, 499,  #
    0x01d2, 499,  #
    0x01d4, 499,  #
    0x01d6, 499,  #
    0x01d8, 499,  #
    0x01da, 499,  #
    0x01dc, 499,  #
    0x01df, 499,  #
    0x01e1, 499,  #
    0x01e3, 499,  #
    0x01e5, 499,  #
    0x01e7, 499,  #
    0x01e9, 499,  #
    0x01eb, 499,  #
    0x01ed, 499,  #
    0x01ef, 499,  #
    0x01f2, 499,  #
    0x01f3, 498,  #
    0x01f5, 499,  #
    0x01fb, 499,  #
    0x01fd, 499,  #
    0x01ff, 499,  #
    0x0201, 499,  #
    0x0203, 499,  #
    0x0205, 499,  #
    0x0207, 499,  #
    0x0209, 499,  #
    0x020b, 499,  #
    0x020d, 499,  #
    0x020f, 499,  #
    0x0211, 499,  #
    0x0213, 499,  #
    0x0215, 499,  #
    0x0217, 499,  #
    0x0253, 290,  #
    0x0254, 294,  #
    0x025b, 297,  #
    0x0260, 295,  #
    0x0263, 293,  #
    0x0268, 291,  #
    0x0269, 289,  #
    0x026f, 289,  #
    0x0272, 287,  #
    0x0283, 282,  #
    0x0288, 282,  #
    0x0292, 281,  #
    0x03ac, 462,  #
    0x03cc, 436,  #
    0x03d0, 438,  #
    0x03d1, 443,  #
    0x03d5, 453,  #
    0x03d6, 446,  #
    0x03e3, 499,  #
    0x03e5, 499,  #
    0x03e7, 499,  #
    0x03e9, 499,  #
    0x03eb, 499,  #
    0x03ed, 499,  #
    0x03ef, 499,  #
    0x03f0, 414,  #
    0x03f1, 420,  #
    0x0461, 499,  #
    0x0463, 499,  #
    0x0465, 499,  #
    0x0467, 499,  #
    0x0469, 499,  #
    0x046b, 499,  #
    0x046d, 499,  #
    0x046f, 499,  #
    0x0471, 499,  #
    0x0473, 499,  #
    0x0475, 499,  #
    0x0477, 499,  #
    0x0479, 499,  #
    0x047b, 499,  #
    0x047d, 499,  #
    0x047f, 499,  #
    0x0481, 499,  #
    0x0491, 499,  #
    0x0493, 499,  #
    0x0495, 499,  #
    0x0497, 499,  #
    0x0499, 499,  #
    0x049b, 499,  #
    0x049d, 499,  #
    0x049f, 499,  #
    0x04a1, 499,  #
    0x04a3, 499,  #
    0x04a5, 499,  #
    0x04a7, 499,  #
    0x04a9, 499,  #
    0x04ab, 499,  #
    0x04ad, 499,  #
    0x04af, 499,  #
    0x04b1, 499,  #
    0x04b3, 499,  #
    0x04b5, 499,  #
    0x04b7, 499,  #
    0x04b9, 499,  #
    0x04bb, 499,  #
    0x04bd, 499,  #
    0x04bf, 499,  #
    0x04c2, 499,  #
    0x04c4, 499,  #
    0x04c8, 499,  #
    0x04cc, 499,  #
    0x04d1, 499,  #
    0x04d3, 499,  #
    0x04d5, 499,  #
    0x04d7, 499,  #
    0x04d9, 499,  #
    0x04db, 499,  #
    0x04dd, 499,  #
    0x04df, 499,  #
    0x04e1, 499,  #
    0x04e3, 499,  #
    0x04e5, 499,  #
    0x04e7, 499,  #
    0x04e9, 499,  #
    0x04eb, 499,  #
    0x04ef, 499,  #
    0x04f1, 499,  #
    0x04f3, 499,  #
    0x04f5, 499,  #
    0x04f9, 499,  #
    0x1e01, 499,  #
    0x1e03, 499,  #
    0x1e05, 499,  #
    0x1e07, 499,  #
    0x1e09, 499,  #
    0x1e0b, 499,  #
    0x1e0d, 499,  #
    0x1e0f, 499,  #
    0x1e11, 499,  #
    0x1e13, 499,  #
    0x1e15, 499,  #
    0x1e17, 499,  #
    0x1e19, 499,  #
    0x1e1b, 499,  #
    0x1e1d, 499,  #
    0x1e1f, 499,  #
    0x1e21, 499,  #
    0x1e23, 499,  #
    0x1e25, 499,  #
    0x1e27, 499,  #
    0x1e29, 499,  #
    0x1e2b, 499,  #
    0x1e2d, 499,  #
    0x1e2f, 499,  #
    0x1e31, 499,  #
    0x1e33, 499,  #
    0x1e35, 499,  #
    0x1e37, 499,  #
    0x1e39, 499,  #
    0x1e3b, 499,  #
    0x1e3d, 499,  #
    0x1e3f, 499,  #
    0x1e41, 499,  #
    0x1e43, 499,  #
    0x1e45, 499,  #
    0x1e47, 499,  #
    0x1e49, 499,  #
    0x1e4b, 499,  #
    0x1e4d, 499,  #
    0x1e4f, 499,  #
    0x1e51, 499,  #
    0x1e53, 499,  #
    0x1e55, 499,  #
    0x1e57, 499,  #
    0x1e59, 499,  #
    0x1e5b, 499,  #
    0x1e5d, 499,  #
    0x1e5f, 499,  #
    0x1e61, 499,  #
    0x1e63, 499,  #
    0x1e65, 499,  #
    0x1e67, 499,  #
    0x1e69, 499,  #
    0x1e6b, 499,  #
    0x1e6d, 499,  #
    0x1e6f, 499,  #
    0x1e71, 499,  #
    0x1e73, 499,  #
    0x1e75, 499,  #
    0x1e77, 499,  #
    0x1e79, 499,  #
    0x1e7b, 499,  #
    0x1e7d, 499,  #
    0x1e7f, 499,  #
    0x1e81, 499,  #
    0x1e83, 499,  #
    0x1e85, 499,  #
    0x1e87, 499,  #
    0x1e89, 499,  #
    0x1e8b, 499,  #
    0x1e8d, 499,  #
    0x1e8f, 499,  #
    0x1e91, 499,  #
    0x1e93, 499,  #
    0x1e95, 499,  #
    0x1ea1, 499,  #
    0x1ea3, 499,  #
    0x1ea5, 499,  #
    0x1ea7, 499,  #
    0x1ea9, 499,  #
    0x1eab, 499,  #
    0x1ead, 499,  #
    0x1eaf, 499,  #
    0x1eb1, 499,  #
    0x1eb3, 499,  #
    0x1eb5, 499,  #
    0x1eb7, 499,  #
    0x1eb9, 499,  #
    0x1ebb, 499,  #
    0x1ebd, 499,  #
    0x1ebf, 499,  #
    0x1ec1, 499,  #
    0x1ec3, 499,  #
    0x1ec5, 499,  #
    0x1ec7, 499,  #
    0x1ec9, 499,  #
    0x1ecb, 499,  #
    0x1ecd, 499,  #
    0x1ecf, 499,  #
    0x1ed1, 499,  #
    0x1ed3, 499,  #
    0x1ed5, 499,  #
    0x1ed7, 499,  #
    0x1ed9, 499,  #
    0x1edb, 499,  #
    0x1edd, 499,  #
    0x1edf, 499,  #
    0x1ee1, 499,  #
    0x1ee3, 499,  #
    0x1ee5, 499,  #
    0x1ee7, 499,  #
    0x1ee9, 499,  #
    0x1eeb, 499,  #
    0x1eed, 499,  #
    0x1eef, 499,  #
    0x1ef1, 499,  #
    0x1ef3, 499,  #
    0x1ef5, 499,  #
    0x1ef7, 499,  #
    0x1ef9, 499,  #
    0x1f51, 508,  #
    0x1f53, 508,  #
    0x1f55, 508,  #
    0x1f57, 508,  #
    0x1fb3, 509,  #
    0x1fc3, 509,  #
    0x1fe5, 507,  #
    0x1ff3, 509]  #

  tolowerRanges = [
    0x0041,  0x005a, 532,  # A-Z a-z
    0x00c0,  0x00d6, 532,  # - -
    0x00d8,  0x00de, 532,  # - -
    0x0189,  0x018a, 705,  # - -
    0x018e,  0x018f, 702,  # - -
    0x01b1,  0x01b2, 717,  # - -
    0x0388,  0x038a, 537,  # - -
    0x038e,  0x038f, 563,  # - -
    0x0391,  0x03a1, 532,  # - -
    0x03a3,  0x03ab, 532,  # - -
    0x0401,  0x040c, 580,  # - -
    0x040e,  0x040f, 580,  # - -
    0x0410,  0x042f, 532,  # - -
    0x0531,  0x0556, 548,  # - -
    0x10a0,  0x10c5, 548,  # - -
    0x1f08,  0x1f0f, 492,  # - -
    0x1f18,  0x1f1d, 492,  # - -
    0x1f28,  0x1f2f, 492,  # - -
    0x1f38,  0x1f3f, 492,  # - -
    0x1f48,  0x1f4d, 492,  # - -
    0x1f68,  0x1f6f, 492,  # - -
    0x1f88,  0x1f8f, 492,  # - -
    0x1f98,  0x1f9f, 492,  # - -
    0x1fa8,  0x1faf, 492,  # - -
    0x1fb8,  0x1fb9, 492,  # - -
    0x1fba,  0x1fbb, 426,  # - -
    0x1fc8,  0x1fcb, 414,  # - -
    0x1fd8,  0x1fd9, 492,  # - -
    0x1fda,  0x1fdb, 400,  # - -
    0x1fe8,  0x1fe9, 492,  # - -
    0x1fea,  0x1feb, 388,  # - -
    0x1ff8,  0x1ff9, 372,  # - -
    0x1ffa,  0x1ffb, 374,  # - -
    0x2160,  0x216f, 516,  # - -
    0x24b6,  0x24cf, 526,  # - -
    0xff21,  0xff3a, 532]  # - -

  tolowerSinglets = [
    0x0100, 501,  #
    0x0102, 501,  #
    0x0104, 501,  #
    0x0106, 501,  #
    0x0108, 501,  #
    0x010a, 501,  #
    0x010c, 501,  #
    0x010e, 501,  #
    0x0110, 501,  #
    0x0112, 501,  #
    0x0114, 501,  #
    0x0116, 501,  #
    0x0118, 501,  #
    0x011a, 501,  #
    0x011c, 501,  #
    0x011e, 501,  #
    0x0120, 501,  #
    0x0122, 501,  #
    0x0124, 501,  #
    0x0126, 501,  #
    0x0128, 501,  #
    0x012a, 501,  #
    0x012c, 501,  #
    0x012e, 501,  #
    0x0130, 301,  #  i
    0x0132, 501,  #
    0x0134, 501,  #
    0x0136, 501,  #
    0x0139, 501,  #
    0x013b, 501,  #
    0x013d, 501,  #
    0x013f, 501,  #
    0x0141, 501,  #
    0x0143, 501,  #
    0x0145, 501,  #
    0x0147, 501,  #
    0x014a, 501,  #
    0x014c, 501,  #
    0x014e, 501,  #
    0x0150, 501,  #
    0x0152, 501,  #
    0x0154, 501,  #
    0x0156, 501,  #
    0x0158, 501,  #
    0x015a, 501,  #
    0x015c, 501,  #
    0x015e, 501,  #
    0x0160, 501,  #
    0x0162, 501,  #
    0x0164, 501,  #
    0x0166, 501,  #
    0x0168, 501,  #
    0x016a, 501,  #
    0x016c, 501,  #
    0x016e, 501,  #
    0x0170, 501,  #
    0x0172, 501,  #
    0x0174, 501,  #
    0x0176, 501,  #
    0x0178, 379,  #
    0x0179, 501,  #
    0x017b, 501,  #
    0x017d, 501,  #
    0x0181, 710,  #
    0x0182, 501,  #
    0x0184, 501,  #
    0x0186, 706,  #
    0x0187, 501,  #
    0x018b, 501,  #
    0x0190, 703,  #
    0x0191, 501,  #
    0x0193, 705,  #
    0x0194, 707,  #
    0x0196, 711,  #
    0x0197, 709,  #
    0x0198, 501,  #
    0x019c, 711,  #
    0x019d, 713,  #
    0x01a0, 501,  #
    0x01a2, 501,  #
    0x01a4, 501,  #
    0x01a7, 501,  #
    0x01a9, 718,  #
    0x01ac, 501,  #
    0x01ae, 718,  #
    0x01af, 501,  #
    0x01b3, 501,  #
    0x01b5, 501,  #
    0x01b7, 719,  #
    0x01b8, 501,  #
    0x01bc, 501,  #
    0x01c4, 502,  #
    0x01c5, 501,  #
    0x01c7, 502,  #
    0x01c8, 501,  #
    0x01ca, 502,  #
    0x01cb, 501,  #
    0x01cd, 501,  #
    0x01cf, 501,  #
    0x01d1, 501,  #
    0x01d3, 501,  #
    0x01d5, 501,  #
    0x01d7, 501,  #
    0x01d9, 501,  #
    0x01db, 501,  #
    0x01de, 501,  #
    0x01e0, 501,  #
    0x01e2, 501,  #
    0x01e4, 501,  #
    0x01e6, 501,  #
    0x01e8, 501,  #
    0x01ea, 501,  #
    0x01ec, 501,  #
    0x01ee, 501,  #
    0x01f1, 502,  #
    0x01f2, 501,  #
    0x01f4, 501,  #
    0x01fa, 501,  #
    0x01fc, 501,  #
    0x01fe, 501,  #
    0x0200, 501,  #
    0x0202, 501,  #
    0x0204, 501,  #
    0x0206, 501,  #
    0x0208, 501,  #
    0x020a, 501,  #
    0x020c, 501,  #
    0x020e, 501,  #
    0x0210, 501,  #
    0x0212, 501,  #
    0x0214, 501,  #
    0x0216, 501,  #
    0x0386, 538,  #
    0x038c, 564,  #
    0x03e2, 501,  #
    0x03e4, 501,  #
    0x03e6, 501,  #
    0x03e8, 501,  #
    0x03ea, 501,  #
    0x03ec, 501,  #
    0x03ee, 501,  #
    0x0460, 501,  #
    0x0462, 501,  #
    0x0464, 501,  #
    0x0466, 501,  #
    0x0468, 501,  #
    0x046a, 501,  #
    0x046c, 501,  #
    0x046e, 501,  #
    0x0470, 501,  #
    0x0472, 501,  #
    0x0474, 501,  #
    0x0476, 501,  #
    0x0478, 501,  #
    0x047a, 501,  #
    0x047c, 501,  #
    0x047e, 501,  #
    0x0480, 501,  #
    0x0490, 501,  #
    0x0492, 501,  #
    0x0494, 501,  #
    0x0496, 501,  #
    0x0498, 501,  #
    0x049a, 501,  #
    0x049c, 501,  #
    0x049e, 501,  #
    0x04a0, 501,  #
    0x04a2, 501,  #
    0x04a4, 501,  #
    0x04a6, 501,  #
    0x04a8, 501,  #
    0x04aa, 501,  #
    0x04ac, 501,  #
    0x04ae, 501,  #
    0x04b0, 501,  #
    0x04b2, 501,  #
    0x04b4, 501,  #
    0x04b6, 501,  #
    0x04b8, 501,  #
    0x04ba, 501,  #
    0x04bc, 501,  #
    0x04be, 501,  #
    0x04c1, 501,  #
    0x04c3, 501,  #
    0x04c7, 501,  #
    0x04cb, 501,  #
    0x04d0, 501,  #
    0x04d2, 501,  #
    0x04d4, 501,  #
    0x04d6, 501,  #
    0x04d8, 501,  #
    0x04da, 501,  #
    0x04dc, 501,  #
    0x04de, 501,  #
    0x04e0, 501,  #
    0x04e2, 501,  #
    0x04e4, 501,  #
    0x04e6, 501,  #
    0x04e8, 501,  #
    0x04ea, 501,  #
    0x04ee, 501,  #
    0x04f0, 501,  #
    0x04f2, 501,  #
    0x04f4, 501,  #
    0x04f8, 501,  #
    0x1e00, 501,  #
    0x1e02, 501,  #
    0x1e04, 501,  #
    0x1e06, 501,  #
    0x1e08, 501,  #
    0x1e0a, 501,  #
    0x1e0c, 501,  #
    0x1e0e, 501,  #
    0x1e10, 501,  #
    0x1e12, 501,  #
    0x1e14, 501,  #
    0x1e16, 501,  #
    0x1e18, 501,  #
    0x1e1a, 501,  #
    0x1e1c, 501,  #
    0x1e1e, 501,  #
    0x1e20, 501,  #
    0x1e22, 501,  #
    0x1e24, 501,  #
    0x1e26, 501,  #
    0x1e28, 501,  #
    0x1e2a, 501,  #
    0x1e2c, 501,  #
    0x1e2e, 501,  #
    0x1e30, 501,  #
    0x1e32, 501,  #
    0x1e34, 501,  #
    0x1e36, 501,  #
    0x1e38, 501,  #
    0x1e3a, 501,  #
    0x1e3c, 501,  #
    0x1e3e, 501,  #
    0x1e40, 501,  #
    0x1e42, 501,  #
    0x1e44, 501,  #
    0x1e46, 501,  #
    0x1e48, 501,  #
    0x1e4a, 501,  #
    0x1e4c, 501,  #
    0x1e4e, 501,  #
    0x1e50, 501,  #
    0x1e52, 501,  #
    0x1e54, 501,  #
    0x1e56, 501,  #
    0x1e58, 501,  #
    0x1e5a, 501,  #
    0x1e5c, 501,  #
    0x1e5e, 501,  #
    0x1e60, 501,  #
    0x1e62, 501,  #
    0x1e64, 501,  #
    0x1e66, 501,  #
    0x1e68, 501,  #
    0x1e6a, 501,  #
    0x1e6c, 501,  #
    0x1e6e, 501,  #
    0x1e70, 501,  #
    0x1e72, 501,  #
    0x1e74, 501,  #
    0x1e76, 501,  #
    0x1e78, 501,  #
    0x1e7a, 501,  #
    0x1e7c, 501,  #
    0x1e7e, 501,  #
    0x1e80, 501,  #
    0x1e82, 501,  #
    0x1e84, 501,  #
    0x1e86, 501,  #
    0x1e88, 501,  #
    0x1e8a, 501,  #
    0x1e8c, 501,  #
    0x1e8e, 501,  #
    0x1e90, 501,  #
    0x1e92, 501,  #
    0x1e94, 501,  #
    0x1ea0, 501,  #
    0x1ea2, 501,  #
    0x1ea4, 501,  #
    0x1ea6, 501,  #
    0x1ea8, 501,  #
    0x1eaa, 501,  #
    0x1eac, 501,  #
    0x1eae, 501,  #
    0x1eb0, 501,  #
    0x1eb2, 501,  #
    0x1eb4, 501,  #
    0x1eb6, 501,  #
    0x1eb8, 501,  #
    0x1eba, 501,  #
    0x1ebc, 501,  #
    0x1ebe, 501,  #
    0x1ec0, 501,  #
    0x1ec2, 501,  #
    0x1ec4, 501,  #
    0x1ec6, 501,  #
    0x1ec8, 501,  #
    0x1eca, 501,  #
    0x1ecc, 501,  #
    0x1ece, 501,  #
    0x1ed0, 501,  #
    0x1ed2, 501,  #
    0x1ed4, 501,  #
    0x1ed6, 501,  #
    0x1ed8, 501,  #
    0x1eda, 501,  #
    0x1edc, 501,  #
    0x1ede, 501,  #
    0x1ee0, 501,  #
    0x1ee2, 501,  #
    0x1ee4, 501,  #
    0x1ee6, 501,  #
    0x1ee8, 501,  #
    0x1eea, 501,  #
    0x1eec, 501,  #
    0x1eee, 501,  #
    0x1ef0, 501,  #
    0x1ef2, 501,  #
    0x1ef4, 501,  #
    0x1ef6, 501,  #
    0x1ef8, 501,  #
    0x1f59, 492,  #
    0x1f5b, 492,  #
    0x1f5d, 492,  #
    0x1f5f, 492,  #
    0x1fbc, 491,  #
    0x1fcc, 491,  #
    0x1fec, 493,  #
    0x1ffc, 491]  #

  toTitleSinglets = [
    0x01c4, 501,  #
    0x01c6, 499,  #
    0x01c7, 501,  #
    0x01c9, 499,  #
    0x01ca, 501,  #
    0x01cc, 499,  #
    0x01f1, 501,  #
    0x01f3, 499]  #

proc binarySearch(c: RuneImpl, tab: openArray[RuneImpl], len, stride: int): int =
  var n = len
  var t = 0
  while n > 1:
    var m = n div 2
    var p = t + m*stride
    if c >= tab[p]:
      t = p
      n = n-m
    else:
      n = m
  if n != 0 and c >= tab[t]:
    return t
  return -1

proc toLower*(c: Rune): Rune {.rtl, extern: "nuc$1", procvar.} =
  ## Converts `c` into lower case. This works for any Unicode character.
  ## If possible, prefer `toLower` over `toUpper`.
  var c = RuneImpl(c)
  var p = binarySearch(c, tolowerRanges, len(tolowerRanges) div 3, 3)
  if p >= 0 and c >= tolowerRanges[p] and c <= tolowerRanges[p+1]:
    return Rune(c + tolowerRanges[p+2] - 500)
  p = binarySearch(c, tolowerSinglets, len(tolowerSinglets) div 2, 2)
  if p >= 0 and c == tolowerSinglets[p]:
    return Rune(c + tolowerSinglets[p+1] - 500)
  return Rune(c)

proc toUpper*(c: Rune): Rune {.rtl, extern: "nuc$1", procvar.} =
  ## Converts `c` into upper case. This works for any Unicode character.
  ## If possible, prefer `toLower` over `toUpper`.
  var c = RuneImpl(c)
  var p = binarySearch(c, toupperRanges, len(toupperRanges) div 3, 3)
  if p >= 0 and c >= toupperRanges[p] and c <= toupperRanges[p+1]:
    return Rune(c + toupperRanges[p+2] - 500)
  p = binarySearch(c, toupperSinglets, len(toupperSinglets) div 2, 2)
  if p >= 0 and c == toupperSinglets[p]:
    return Rune(c + toupperSinglets[p+1] - 500)
  return Rune(c)

proc isDigit*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is a *numeric* Unicode character
  var c = RuneImpl(c)
  var p = binarySearch(c, numRanges, len(numRanges) div 2, 2)
  if p >= 0 and c >= numRanges[p] and c <= numRanges[p+1]:
    return true
  p = binarySearch(c, numSinglets, len(numSinglets), 1)
  if p >= 0 and c == numSinglets[p]:
    return true

proc isAlnum*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is an *alphanumeric* Unicode character (i.e. in the alpha or numeric range)
  if isAlpha(c) or isDigit(c):
    return true

proc toTitle*(c: Rune): Rune {.rtl, extern: "nuc$1", procvar.} =
  var c = RuneImpl(c)
  var p = binarySearch(c, toTitleSinglets, len(toTitleSinglets) div 2, 2)
  if p >= 0 and c == toTitleSinglets[p]:
    return Rune(c + toTitleSinglets[p+1] - 500)
  return Rune(c)

proc isLower*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is a lower case Unicode character
  ## If possible, prefer `isLower` over `isUpper`.
  var c = RuneImpl(c)
  # Note: toUpperRanges is correct here!
  var p = binarySearch(c, toupperRanges, len(toupperRanges) div 3, 3)
  if p >= 0 and c >= toupperRanges[p] and c <= toupperRanges[p+1]:
    return true
  p = binarySearch(c, toupperSinglets, len(toupperSinglets) div 2, 2)
  if p >= 0 and c == toupperSinglets[p]:
    return true

proc isUpper*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is a upper case Unicode character
  ## If possible, prefer `isLower` over `isUpper`.
  var c = RuneImpl(c)
  # Note: toLowerRanges is correct here!
  var p = binarySearch(c, tolowerRanges, len(tolowerRanges) div 3, 3)
  if p >= 0 and c >= tolowerRanges[p] and c <= tolowerRanges[p+1]:
    return true
  p = binarySearch(c, tolowerSinglets, len(tolowerSinglets) div 2, 2)
  if p >= 0 and c == tolowerSinglets[p]:
    return true

proc isAlpha*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is an *alpha* Unicode character (i.e. a letter)
  if isUpper(c) or isLower(c):
    return true
  var c = RuneImpl(c)
  var p = binarySearch(c, alphaRanges, len(alphaRanges) div 2, 2)
  if p >= 0 and c >= alphaRanges[p] and c <= alphaRanges[p+1]:
    return true
  p = binarySearch(c, alphaSinglets, len(alphaSinglets), 1)
  if p >= 0 and c == alphaSinglets[p]:
    return true

proc isTitle*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  return isUpper(c) and isLower(c)

proc isWhiteSpace*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is a Unicode whitespace character
  var c = RuneImpl(c)
  var p = binarySearch(c, spaceRanges, len(spaceRanges) div 2, 2)
  if p >= 0 and c >= spaceRanges[p] and c <= spaceRanges[p+1]:
    return true

proc isCombining*(c: Rune): bool {.rtl, extern: "nuc$1", procvar.} =
  ## returns true iff `c` is a Unicode combining character
  var c = RuneImpl(c)

  # Optimized to return false immediately for ASCII
  return c >= 0x0300 and (c <= 0x036f or
    (c >= 0x1ab0 and c <= 0x1aff) or
    (c >= 0x1dc0 and c <= 0x1dff) or
    (c >= 0x20d0 and c <= 0x20ff) or
    (c >= 0xfe20 and c <= 0xfe2f))

iterator runes*(s: string): Rune =
  ## iterates over any unicode character of the string `s`.
  var
    i = 0
    result: Rune
  while i < len(s):
    fastRuneAt(s, i, result, true)
    yield result

proc cmpRunesIgnoreCase*(a, b: string): int {.rtl, extern: "nuc$1", procvar.} =
  ## compares two UTF8 strings and ignores the case. Returns:
  ##
  ## | 0 iff a == b
  ## | < 0 iff a < b
  ## | > 0 iff a > b
  var i = 0
  var j = 0
  var ar, br: Rune
  while i < a.len and j < b.len:
    # slow path:
    fastRuneAt(a, i, ar)
    fastRuneAt(b, j, br)
    result = RuneImpl(toLower(ar)) - RuneImpl(toLower(br))
    if result != 0: return
  result = a.len - b.len

proc reversed*(s: string): string =
  ## returns the reverse of `s`, interpreting it as unicode characters. Unicode
  ## combining characters are correctly interpreted as well:
  ##
  ## .. code-block:: nim
  ##
  ##   assert reversed("Reverse this!") == "!siht esreveR"
  ##   assert reversed("先秦兩漢") == "漢兩秦先"
  ##   assert reversed("as⃝df̅") == "f̅ds⃝a"
  ##   assert reversed("a⃞b⃞c⃞") == "c⃞b⃞a⃞"
  var
    i = 0
    lastI = 0
    newPos = len(s) - 1
    blockPos = 0
    r: Rune

  template reverseUntil(pos): stmt =
    var j = pos - 1
    while j > blockPos:
      result[newPos] = s[j]
      dec j
      dec newPos
    blockPos = pos - 1

  result = newString(len(s))

  while i < len(s):
    lastI = i
    fastRuneAt(s, i, r, true)
    if not isCombining(r):
      reverseUntil(lastI)

  reverseUntil(len(s))

when isMainModule:
  let
    someString = "öÑ"
    someRunes = @[runeAt(someString, 0), runeAt(someString, 2)]
    compared = (someString == $someRunes)
  assert compared == true

  assert reversed("Reverse this!") == "!siht esreveR"
  assert reversed("先秦兩漢") == "漢兩秦先"
  assert reversed("as⃝df̅") == "f̅ds⃝a"
  assert reversed("a⃞b⃞c⃞") == "c⃞b⃞a⃞"
