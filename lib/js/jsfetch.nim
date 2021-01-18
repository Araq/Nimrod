## - Fetch for the JavaScript target: https://developer.mozilla.org/docs/Web/API/Fetch_API
import jsheaders
from httpcore import HttpMethod
export HttpMethod

when not defined(js):
  {.fatal: "Module jsfetch is designed to be used with the JavaScript backend.".}

type
  FetchOptions* = ref object  ## Options for Fetch API.
    keepalive: bool
    metod {.importjs: "method".}: cstring
    body, integrity, referrer, mode, credentials, cache, redirect, referrerPolicy: cstring

  FetchModes* = enum  ## JavaScript Fetch API mode options.
    fmCors = "cors".cstring
    fmNoCors = "no-cors".cstring
    fmSameOrigin = "same-origin".cstring

  FetchCredentials* = enum  ## JavaScript Fetch API Credential options.
    fcInclude = "include".cstring
    fcSameOrigin = "same-origin".cstring
    fcOmit = "omit".cstring

  FetchCaches* = enum  ## https://developer.mozilla.org/docs/Web/API/Request/cache
    fchDefault = "default".cstring
    fchNoStore = "no-store".cstring
    fchReload = "reload".cstring
    fchNoCache = "no-cache".cstring
    fchForceCache = "force-cache".cstring

  FetchRedirects* = enum  ## JavaScript Fetch API Redirects options.
    frFollow = "follow".cstring
    frError = "error".cstring
    frManual = "manual".cstring

  FetchReferrerPolicies* = enum  ## JavaScript Fetch API Referrer Policy options.
    frpNoReferrer = "no-referrer".cstring
    frpNoReferrerWhenDowngrade = "no-referrer-when-downgrade".cstring
    frpOrigin = "origin".cstring
    frpOriginWhenCrossOrigin = "origin-when-cross-origin".cstring
    frpUnsafeUrl = "unsafe-url".cstring

  Response* = ref object  ## https://developer.mozilla.org/en-US/docs/Web/API/Response
    myBodyUsed, ok, redirected: bool
    tipe {.importjs: "type".}: cstring
    url, statusText: cstring
    status: cushort
    headers: Headers


template fetchMethodToCstring(metod: HttpMethod): cstring =
  ## Template that takes an `HttpMethod` and returns an *Uppercase* `cstring`,
  ## but *only* for the HTTP Methods that are supported by the fetch API.
  ## High performance and minimal code compared to just `$(HttpMethod)`.
  assert metod notin {HttpTrace, HttpOptions, HttpConnect}, "HTTP Method not supported by Fetch API"
  case metod
  of HttpHead:   "HEAD".cstring
  of HttpGet:    "GET".cstring
  of HttpPost:   "POST".cstring
  of HttpPut:    "PUT".cstring
  of HttpDelete: "DELETE".cstring
  of HttpPatch:  "PATCH".cstring
  else:          "GET".cstring

func hasFetch*(): bool {.importjs: "(() => { return !!window.fetch })()".}
  ## Convenience func to detect Fetch API support, returns `true` if Fetch is supported.

func unsafeNewFetchOptions*(metod, body, mode, credentials, cache, referrerPolicy: cstring,
    keepalive: bool, redirect = "follow".cstring, referrer = "client".cstring, integrity = "".cstring): FetchOptions {.importjs:
    "{method: #, body: #, mode: #, credentials: #, cache: #, referrerPolicy: #, keepalive: #, redirect: #, referrer: #, integrity: #}".}
  ## **Unsafe** `newfetchOptions`. Low-level func for optimization.

func newfetchOptions*(metod: HttpMethod, body: cstring,
    mode: FetchModes, credentials: FetchCredentials, cache: FetchCaches, referrerPolicy: FetchReferrerPolicies,
    keepalive: bool, redirect = frFollow, referrer = "client".cstring, integrity = "".cstring): FetchOptions =
  ## Constructor for `FetchOptions`.
  result = FetchOptions(metod: fetchMethodTocstring(metod), body: body, mode: $mode,
    credentials: $credentials, cache: $cache, referrerPolicy: $referrerPolicy,
    keepalive: keepalive, redirect: $redirect , referrer: referrer, integrity: integrity)

func fetchToCstring*(url: cstring): cstring {.importjs: "await fetch(#).then(response => response.text()).then(text => text)".}
  ## Convenience func for `fetch()` API that returns a `cstring` directly.

func fetchToCstring*(url: cstring, options: FetchOptions): cstring {.importjs: "await fetch(#, #).then(response => response.text()).then(text => text)".}
  ## Convenience func for `fetch()` API that returns a `cstring` directly.

func fetch*(url: cstring): Response {.importjs: "await fetch(#).then(response => response)".}
  ## `fetch()` API, simple `GET` only, returns a `Response`.

func fetch*(url: cstring, options: FetchOptions): Response {.importjs: "await fetch(#, #).then(response => response)".}
  ## `fetch()` API that takes a `FetchOptions`, returns a `Response`.



runnableExamples:
  when defined(nimJsFetchTests):
    block:
      let options = unsafeNewFetchOptions(
        metod =  "POST".cstring,
        body = """{"key": "value"}""".cstring,
        mode = "no-cors".cstring,
        credentials = "omit".cstring,
        cache = "no-cache".cstring,
        referrerPolicy = "no-referrer".cstring,
        keepalive = false,
        redirect = "follow".cstring,
        referrer = "client".cstring,
        integrity = "".cstring
      )
      doAssert options is FetchOptions
      echo fetchToCstring(r"http://httpbin.org/post", options)
