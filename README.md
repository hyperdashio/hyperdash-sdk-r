# Hyperdash R SDK

The Hyperdash R SDK is the official SDK for [Hyperdash.io](https://hyperdash.io). Once installed, the SDK automatically monitors your machine learning jobs.

## Installation

```r
install.packages("devtools")
library("devtools")
devtools::install_github("hyperdashio/hyperdash-sdk-r")
```

## Usage

The Hyperdash SDK requires a valid API key in order to function. The easiest way to obtain one is to install our Python SDK `pip install --upgrade pip && pip install hyperdash` and then run `hyperdash login` (if you already have an account) and `hyperdash signup` (if you don't), either of which will automatically install one for you.

If you'd rather manage your API key manually, then review the "API Key Storage" section below.

### Monitoring an R function

Import the Hyperdash library
```r
library(hyperdash)
```

and then simply pass any R function to the Monitor function, along with the name of the job as you'd like it to be recorded in Hyperdash.

Note: The provided function must accept an argument called hd.client which will be passed into the function and exposes various Hyperdash functionality. For example, if you want to print something, but also have it available in your Hyperdash logs, you can call 

```r
hd.client$print("Your log message here")
``` 

instead of the usual 

```r
print("Your log message here)
```

```r
Monitor(function(hd.client) {
  hd.client$print("Begining machine learning...")
  Sys.sleep(2)
  hd.client$print("25% complete...")
  Sys.sleep(2)
  hd.client$print("50% complete...")
  Sys.sleep(2)
  hd.client$print("75% complete...")
  Sys.sleep(2)
  hd.client$print("100% complete...")
  Sys.sleep(2)
  hd.client$print("Done!")
}, "My test hyperdash job")
```

### API key storage

The Hyperdash R SDK will always search for your API key in `~/.hyperdash/hyperdash.json` and it expects a JSON file with the following format:

```
{
  "api_key": "YOUR_API_KEY_HERE
}
```

## Development
Clone the repo and make changes!

If any of the changes you make require the documentation to be updated, open an R repl in the `hyperdash` directory and run the following commands:

```r
library(devtools)
library(roxygen2)
document()
```

Note you may need to install those dependencies by running the following commands:

```r
install.packages("devtools")
install.packages("roxygen2")
```