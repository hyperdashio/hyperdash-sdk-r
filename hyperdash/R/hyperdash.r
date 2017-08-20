library(httr)
library(uuid)
library(parallel)
library(rjson)

kTypeRunStarted <- 'run_started'
kTypeRunEnded <- 'run_ended'
kTypeLog <- 'log'
kTypeHeartbeat <- 'heartbeat'

kOutcomeSuccess <- 'success'
kOutcomeFailure <- 'failure'
kOutcomeUserCanceled <- 'user_canceled'
kLevelInfo <- 'INFO'

kHyperdashJSONLocation <- "~/.hyperdash/hyperdash.json"

kHeartbeatExports <- list("HeartbeatLoop", "SendSDKMessage", "POST", "CreateHeartbeatMessage", "CreateSDKMessage", "kTypeHeartbeat", "add_headers")

#' Monitor monitors a machine learning job
#'
#' This function helps you monitor a machine learning job. It will
#' keep track of when the job starts/ends, as well as any logs that
#' are emitted using the hd.client.print() function.
#' @param func A function that when invoked, will execute the job you want to monitor.
#'   Note: The provided function must accept an argument called hd.client
#'   which will be passed into the function and exposes various Hyperdash
#'   functionality. For example, if you want to print something, but also have
#'   it available in your Hyperdash logs, you can call hd.client$print("Your log message here")
#' @param job.name The name of the job that you want to monitor.
#' @export
#' @examples
#' Monitor(function(hd.client) {
#'   hd.client$print("Begining machine learning...")
#'   Sys.sleep(2)
#'   hd.client$print("25% complete...")
#'   Sys.sleep(2)
#'   hd.client$print("50% complete...")
#'   Sys.sleep(2)
#'   hd.client$print("75% complete...")
#'   Sys.sleep(2)
#'   hd.client$print("100% complete...")
#'   Sys.sleep(2)
#'   hd.client$print("Done!")
#' }, "My test hyperdash job")
Monitor <- function(func, job.name) {
  api.key <- GetAPIKey()
  # If we can't find an API key, just run their code
  if (is.null(api.key)) {
    print("Unable to locate Hyperdash API key, please make sure its located in the hyperdash.json file.")
    # Dummy hd.client so they don't need to change their code
    func(hd.client=NewDummyHDClient())
  }

  sdk.run.uuid <- UUIDgenerate()
  SendSDKMessage(CreateRunStartedMessage(sdk.run.uuid, job.name), api.key)
  # Capture result of user's function
  # Cluster of size 1 in which we will run the heartbeat code
  heartbeatCluster = makeCluster(1)
  # Since we're using the non-forking version of the makeCluster API (to support Windows) we
  # need to manually export every function that will be used by the heartbeat process.
  clusterExport(heartbeatCluster, kHeartbeatExports)
  # Capture the result of the user's code so we can return it
  outcome <- kOutcomeSuccess
  result <- tryCatch(
    # Use sendCall instead of clusterCall to schedule work on the cluster without blocking
    # the main thread of execution. Its important that we invoke this inside the tryCatch
    # block so incase anything happens we're sure to cleanup the cluster in the finally
    # call and not leave any zombie heartbeat processes around.
    {
      parallel:::sendCall(heartbeatCluster[[1]], HeartbeatLoop, list(sdk.run.uuid, api.key))
      func(hd.client=NewHDClient(sdk.run.uuid, api.key))
    },
    # Log warning
    warning = function(cond) {
      SendSDKMessage(CreateLogMessage(sdk.run.uuid, cond$message), api.key)
      cond
    },
    # Log errors and mark job as failed
    error = function(cond) {
      SendSDKMessage(CreateLogMessage(sdk.run.uuid, cond$message), api.key)
      outcome <<- kOutcomeFailure
      cond
    },
    interrupt = function(cond) {
      outcome <<- kOutcomeUserCanceled
      cond
    },
    # Cleanup cluster
    finally = function() {
      stopCluster(heartbeatCluster)
    }
  )
  SendSDKMessage(CreateRunEndedMessage(sdk.run.uuid, outcome), api.key)
  # Return result of user's function
  result
}

NewHDClient <- function(sdk.run.uuid, api.key) {
  hd.print <- function(s) {
    print(s)
    SendSDKMessage(CreateLogMessage(sdk.run.uuid, s), api.key)
  }
  # Use a named list as an "object"
  list(print=hd.print)
}

NewDummyHDClient <- function() {
  list(print=print)
}

SendSDKMessage <- function(message, api.key) {
  r <- POST(
    "https://hyperdash.io/api/v1/sdk/http",
    add_headers("x-hyperdash-auth"=api.key),
    body=message,
    encode="json"
  )
}

HeartbeatLoop <- function(sdk.run.uuid, api.key) {
  repeat {
    SendSDKMessage(CreateHeartbeatMessage(sdk.run.uuid), api.key)
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

GetAPIKey <- function() {
  path <- path.expand(kHyperdashJSONLocation)
  errorMessage <- paste("Could not locate hyperdash.json file, please make sure its located at:", kHyperdashJSONLocation, "and is valid JSON", sep=" ")
  hyperdash.json <- tryCatch(
    fromJSON(file=path)$api_key,
    warning = function(cond) {
      print(errorMessage)
      NULL    
    },
    error = function(cond) {
      print(errorMessage)
      NULL
    }
  )
}
