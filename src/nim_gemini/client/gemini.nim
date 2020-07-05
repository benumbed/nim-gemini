## 
## Gemini client library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import asyncdispatch
import chronicles
import strformat
import strutils
import net
import streams
import uri as uriUtils

# let uri = "gemini://gemini.circumlunar.space/"
# let uri = "gemini://gus.guru/known-hosts"
let uri = "gemini://gemini.conman.org/test/torture/"

type ResponseData = object
    uri: string
    host: string
    port: int
    status: int
    meta: string
    body: Stream

proc successHandler(rd: ResponseData) =
    ##
    info "Successful response from server", status=rd.status, mimeType=rd.meta
    echo fmt"{rd.body.readAll()}"

proc temporaryFailureHandler(rd: ResponseData) =
    error "Server returned TEMPORARY FAILURE error", status=rd.status, errorMsg=rd.meta, host=rd.host, uri=rd.uri

proc permanentFailureHandler(rd: ResponseData) =
    error "Server returned PERMANENT FAILURE error", status=rd.status, errorMsg=rd.meta, host=rd.host, uri=rd.uri


proc sendRequest*(uri: string, tlsVerify = CVerifyNone, tlsVersion = protTLSv1, connectTimeout = 5000, readTimeout = 500) = 
    ## Testing some Gemini stuff
    ## 
    let parsedUri = parseUri(uri)
    let host = parsedUri.hostname
    let port = if parsedUri.port.len == 0: 1965 else: parsedUri.port.parseInt()
    
    let sock = newSocket(buffered=true)
    sock.connect(host, Port(port), timeout=connectTimeout)

    #  Set up TLS context
    let ctxt = newContext(protVersion = tlsVersion, verifyMode = tlsVerify)
    ctxt.wrapConnectedSocket(sock, handshakeAsClient)

    # Request
    let outStr = newStringStream()
    outStr.write(uri)
    outStr.write("\r\n")
    outStr.setPosition(0)
    sock.send(outStr.readAll())

    # Response
    let statStr = sock.recv(2, readTimeout)
    let status = statStr.parseInt()

    # 1 byte for space, 1024 for META, 2 for \c\n
    # Note that this may not be the case, we figure that out below
    let rawData = sock.recv(1027, readTimeout)
    let data = rawData[1..(rawData.len-1)]
    var toks = data.split("\c\n")
    var additionalData = rawData.len == 1027

    if toks.len > 2:
        toks[1] = toks[1..(toks.len-1)].join("\c\n")

    let rd = ResponseData(
        uri: uri,
        host: host,
        port: port,
        status: status,
        meta: toks[0],
        body: newStringStream()
    )


    if status >= 10 and status < 20:
        error "INPUT status codes not implemented"

    elif status >= 20 and status < 30:
        # 2x statuses are the only ones that return body data
        rd.body.write(toks[1])

        while additionalData:
            let chunk = sock.recv(2048, 5000)
            if chunk.len < 1:
                additionalData = false;

            rd.body.write(chunk)
        
        rd.body.setPosition(0)
        rd.successHandler()

    elif status >= 30 and status < 40:
        error "REDIRECT status codes not implemented"

    elif status >= 40 and status < 50:
        rd.temporaryFailureHandler()

    elif status >= 40 and status < 50:
        rd.permanentFailureHandler()

    elif status >= 30 and status < 40:
        error "CLIENT CERTIFICATE REQUIRED status codes not implemented"



when isMainModule:
    sendRequest(uri=uri, tlsVersion = protSSLv23)
