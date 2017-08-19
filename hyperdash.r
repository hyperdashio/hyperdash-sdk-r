library(httr)
library(uuid)
library(parallel)

kTypeRunStarted <- 'run_started'
kTypeRunEnded <- 'run_ended'
kTypeLog <- 'log'
kTypeHeartbeat <- 'heartbeat'

kOutcomeSuccess <- 'success'
kLevelInfo <- 'INFO'

MonitorJob <- function(func, job.name) {
  sdk.run.uuid <- UUIDgenerate()
  SendSDKMessage(CreateRunStartedMessage(sdk.run.uuid, job.name))
  # Capture result of user's function
  # TODO: Catch exceptions
  # Start background process to heartbeat on a regular basis
  backgroundHeartbeat = mcparallel(HeartbeatLoop(sdk.run.uuid))
  result <- func(hd.client=NewHDClient(sdk.run.uuid))
  SendSDKMessage(CreateRunEndedMessage(sdk.run.uuid, kOutcomeSuccess))
  # Return result of user's function
  result
}

NewHDClient <- function(sdk.run.uuid) {
  hd.print <- function(s) {
    print(s)
    SendSDKMessage(CreateLogMessage(sdk.run.uuid, s))
  }
  # Use a named list as an "object"
  list(print=hd.print)
}

SendSDKMessage <- function(message) {
  r <- POST(
    "https://hyperdash.io/api/v1/sdk/http",
    add_headers("x-hyperdash-auth"="LkVFfGuVck0DdDjM5y/o45759MaUklbItvkPfXNQqGY="),
    body=message,
    encode="json"
  )
}

HeartbeatLoop <- function(sdk.run.uuid) {
  repeat {
    SendSDKMessage(CreateHeartbeatMessage(sdk.run.uuid))
    Sys.sleep(10)
  }
}

CreateHeartbeatMessage <- function(sdk.run.uuid) {
  CreateSDKMessage(sdk.run.uuid, kTypeHeartbeat, list())
}

CreateRunStartedMessage <- function(sdk.run.uuid, job.name) {
  CreateSDKMessage(sdk.run.uuid, kTypeRunStarted, list(job.name=job.name))
}

CreateRunEndedMessage <- function(sdk.run.uuid, final.status) {
  CreateSDKMessage(sdk.run.uuid, kTypeRunEnded, list(final_status = final.status))
}

CreateLogMessage <- function(sdk.run.uuid, s) {
  CreateSDKMessage(sdk.run.uuid, kTypeLog, list(uuid = UUIDgenerate(), level = kLevelInfo, body = s))
}

CreateSDKMessage <- function(sdk.run.uuid, type, payload) {
  list(type=type, timestamp = trunc(as.numeric(Sys.time()) * 1000, prec = 0), sdk_run_uuid = sdk.run.uuid, payload = payload)
}

test <- function(hd.client) {
  hd.client$print("yo")
  Sys.sleep(1)
  hd.client$print("yo")  
  Sys.sleep(1)
  hd.client$print("yo")  
  Sys.sleep(1)
  hd.client$print("yo")
  Sys.sleep(1)
  hd.client$print("yo")
  Sys.sleep(1)
  hd.client$print("yo")
  Sys.sleep(1)
  hd.client$print("yo")
  Sys.sleep(1)
  Sys.sleep(120)
  hd.client$print("done")
}
MonitorJob(test, "testRJob")