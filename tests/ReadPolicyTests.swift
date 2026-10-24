for command in ["04", "2701", "1003", "3101", "2E123400", "ATMA", "ATCSM0", "ATSH123", "010C\r04", "", "\r"] {
    precondition(!ReadPolicy.allowed(command, vehicle: true), command)
}
for command in ["ATI", "ATRV", "0100", "010C", "0902", "03", "07", "0A"] {
    precondition(ReadPolicy.allowed(command, vehicle: true), command)
}
precondition(!ReadPolicy.allowed("010C", vehicle: false))
precondition(ReadPolicy.allowedOnHeader("2103", header:"7E1"))
precondition(!ReadPolicy.allowedOnHeader("2103", header:"7DF"))
precondition(!ReadPolicy.allowedOnHeader("2103", header:"784"))
precondition(ReadPolicy.allowedOnHeader("2101", header:"784"))
precondition(ReadPolicy.allowedOnHeader("2104", header:"7B6"))
precondition(!ReadPolicy.allowedOnHeader("2105", header:"7B6"))
var route = DiagnosticRouteState()
precondition(!route.canRead("2103"))
for c in ["ATSH7E1","ATCRA7E9","ATFCSH7E1","ATFCSD30080A","ATFCSM1"] { route.acknowledge(c) }
precondition(!route.canRead("2103"), "Inherited CAF/CFC/protocol state is unknown")
route.acknowledge("ATCAF1"); route.acknowledge("ATCFC1")
precondition(!route.canRead("2103"), "Protocol must also be acknowledged")
route.acknowledge("ATSP6")
precondition(route.canRead("2103"))
route.acknowledge("ATSH7B6")
precondition(!route.canRead("2104"), "Stale CVT flow control must not authorize AWC read")
for c in ["ATCRA7B7","ATFCSH7B6"] { route.acknowledge(c) }
precondition(route.canRead("2104"))
route.acknowledge("ATSH7DF")
precondition(!route.canRead("010C"))
route.acknowledge("ATFCSM0"); route.acknowledge("ATAR")
precondition(route.canRead("010C"))

print("Native read policy and coherent route assertions passed")

for command in ["2173","2178","217A","217E"] {
    precondition(ReadPolicy.allowed(command,vehicle:true), "Documented body record must be permitted")
    precondition(!ReadPolicy.allowed(command,vehicle:false))
    precondition(ReadPolicy.allowedOnHeader(command,header:"620"))
    precondition(!ReadPolicy.allowedOnHeader(command,header:"7DF"))
    var bodyRoute=DiagnosticRouteState()
    for c in ["ATCAF1","ATCFC1","ATSP6","ATSH620","ATCRA504","ATFCSH620","ATFCSD30080A","ATFCSM1"]{bodyRoute.acknowledge(c)}
    precondition(bodyRoute.canRead(command))
    bodyRoute.acknowledge("ATCRA7E9")
    precondition(!bodyRoute.canRead(command))
}
for command in ["2172","2174","2179","217B","217F","21B0","21B3","1092","3B7A00","307A00"] {
    precondition(!ReadPolicy.allowed(command,vehicle:true), "No neighboring reads, settings or session changes")
}
print("Documented body record policy assertions passed")

for (header,response,commands) in [("688","511",["1A87","1A9C","2134","2122","2123","2120","2121","2110","2111"]),("620","504",["21B2"])] {
    var controlsRoute=DiagnosticRouteState()
    for c in ["ATCAF1","ATCFC1","ATSP6","ATSH"+header,"ATCRA"+response,"ATFCSH"+header,"ATFCSD30080A","ATFCSM1"] {
        precondition(ReadPolicy.allowed(c,vehicle:true),c)
        controlsRoute.acknowledge(c)
    }
    for c in commands {
        precondition(ReadPolicy.allowed(c,vehicle:true),c)
        precondition(!ReadPolicy.allowed(c,vehicle:false))
        precondition(ReadPolicy.allowedOnHeader(c,header:header))
        precondition(!ReadPolicy.allowedOnHeader(c,header:"7DF"))
        precondition(controlsRoute.canRead(c))
    }
    controlsRoute.acknowledge("ATFCSM0")
    precondition(!controlsRoute.canRead(commands[0]))
}
for c in ["2133","2135","2124","21B1","21B3","30340701","303400","30150701","3BB200","1A88","1A90"] {
    precondition(!ReadPolicy.allowed(c,vehicle:true),c)
}
precondition(!ReadPolicy.allowedOnHeader("21B2",header:"688"))
precondition(!ReadPolicy.allowedOnHeader("2134",header:"620"))
print("Parked climate/preferences read policy assertions passed")
