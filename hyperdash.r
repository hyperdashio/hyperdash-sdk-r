library(httr)
library(uuid)
library(parallel)

kTypeRunStarted <- 'run_started'
kTypeRunEnded <- 'run_ended'
kTypeLog <- 'log'
kTypeHeartbeat <- 'heartbeat'

kOutcomeSuccess <- 'success'
kOutcomeFailure <- 'failure'
kLevelInfo <- 'INFO'

kHeartbeatExports <- list("HeartbeatLoop", "SendSDKMessage", "POST", "CreateHeartbeatMessage", "CreateSDKMessage", "kTypeHeartbeat", "add_headers")

MonitorJob <- function(func, job.name) {
  sdk.run.uuid <- UUIDgenerate()
  SendSDKMessage(CreateRunStartedMessage(sdk.run.uuid, job.name))
  # Capture result of user's function
  # Cluster of size 1 in which we will run the heartbeat code
  heartbeatCluster = makeCluster(1)
  # Since we're using the non-forking version of the makeCluster API (to support Windows) we
  # need to manually export every function that will be used by the heartbeat process.
  clusterExport(heartbeatCluster, kHeartbeatExports)
  # Use sendCall instead of clusterCall to schedule work on the cluster without blocking
  # the main thread of execution.
  parallel:::sendCall(heartbeatCluster[[1]], HeartbeatLoop, list(sdk.run.uuid))
  # Capture the result of the user's code so we can return it
  outcome <- kOutcomeSuccess
  result <- tryCatch(
    func(hd.client=NewHDClient(sdk.run.uuid)),
    # Log warning
    warning = function(cond) {
      SendSDKMessage(CreateLogMessage(sdk.run.uuid, cond$message))
      cond
    },
    # Log errors and mark job as failed
    error = function(cond) {
      SendSDKMessage(CreateLogMessage(sdk.run.uuid, cond$message))
      outcome <<- kOutcomeFailure
      cond
    }
  )
  SendSDKMessage(CreateRunEndedMessage(sdk.run.uuid, outcome))    
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
