test <- function(hd.client) {
  hd.client$print("1")
  Sys.sleep(1)
  hd.client$print("2")  
  Sys.sleep(1)
  hd.client$print("3")  
  Sys.sleep(1)
  hd.client$print("4")
  Sys.sleep(1)
  hd.client$print("5")
  Sys.sleep(1)
  hd.client$print("done")
}
MonitorJob(test, "testRJob")