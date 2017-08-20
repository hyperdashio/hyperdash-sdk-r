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

#' MonitorJob monitors a machine learning job
#'
#' This function helps you monitor a machine learning job. It will
#' keep track of when the job starts/ends, as well as any logs that
#' are emitted using the hd_client.print() function.
#' @param func A function that when invoked, will execute the job you want to monitor.
#'   Note: The provided function must accept an argument called hd_client
#'   which will be passed into the function and exposes various Hyperdash
#'   functionality. For example, if you want to print something, but also have
#'   it available in your Hyperdash logs, you can call hd_client$print("Your log message here")
#' @param job.name The name of the job that you want to monitor.
#' @export
#' @examples
#' MonitorJob(function(hd_client) {
#'   hd_client$print("Begining machine learning...")
#'   Sys.sleep(2)
#'   hd_client$print("25% complete...")
#'   Sys.sleep(2)
#'   hd_client$print("50% complete...")
#'   Sys.sleep(2)
#'   hd_client$print("75% complete...")
#'   Sys.sleep(2)
#'   hd_client$print("100% complete...")
#'   Sys.sleep(2)
#'   hd_client$print("Done!")
#' }, "My test hyperdash job")
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
    },
    # Cleanup cluster
    finally = function() {
      stopCluster(heartbeatCluster)
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
    add_headers("x-hyperdash-auth"="<REDACTED>"),
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
  CreateSDKMessage(sdk.run.uuid, kTypeRunStarted, list(job_name=job.name))
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