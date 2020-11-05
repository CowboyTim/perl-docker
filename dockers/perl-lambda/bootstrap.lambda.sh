#!/bin/sh

source $LAMBDA_TASK_ROOT/${_HANDLER%%.*}.sh

# best is to use hardcoded path's for unix tools used here, else the source
# that was done might've changed PATH and we'd be using the wrong curl or
# mktemp to just run this bootstrap
while true
do
    # Request the next event from the Lambda runtime
    HEADERS=$(mktemp)
    EVENT_DATA=$(/usr/bin/curl -sS -LD "$HEADERS" -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")
    INVOCATION_ID=
    while IFS=':' read key value; do
        if [ "$key" = 'Lambda-Runtime-Aws-Request-Id' ]; then
            INVOCATION_ID=${value#*: }
            INVOCATION_ID=${INVOCATION_ID%[[:space:]]}
            INVOCATION_ID=${INVOCATION_ID#[[:space:]]}
            break
        fi
    done < $HEADERS

    # Execute the handler function from the script
    RESPONSE=$("${_HANDLER#*.}" "$EVENT_DATA")

    # Send the response to Lambda runtime
    /usr/bin/curl -sS -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$INVOCATION_ID/response" -d "$RESPONSE"
done
