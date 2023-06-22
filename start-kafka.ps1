$namespace = "k8-felis"

$env:KIND_EXPERIMENTAL_PROVIDER="podman"

function createBIGYAML
{
    $OUTPUT = "outputfile.yaml"
    rm $OUTPUT; touch $OUTPUT

    $yamlfilesToUse = $(ls .\*.yml) + $(ls .\kubernetes-mongodb\*.yml);

    foreach($file in $yamlfilesToUse)
    {
        echo $(cat $file) "---" >> $OUTPUT;
    }

    echo $($(cat $OUTPUT) -replace "reserved-word-for-namespace-123456789", $namespace)  > $OUTPUT;
    kubectl apply -f $OUTPUT;
}

try
{
    Write-Output "Creating Kafka K8 resources"
    
    if($($($(kubectl get namespaces) -match $namespace) -split '\s+').length -ne 0)
    {
        write-host "Detected uncleaned Kafka K8 resources. Deleting..."
        kubectl delete -f "00-namespace.yml"
    }
    
    write-host "Setting up K8 Resources..."
    createBIGYAML($namespace);

    Start-Sleep 1 # wait for the kafkapod to be Up and Running

    write-host "Waiting for Kafka Broker to start..."
    $kafkapod = (kubectl get pods -n $namespace | grep kafka).Split()[0]

    for($status = ""; $status -ne "Running"; $status = $($(kubectl get pods -n $namespace $kafkapod) -split '\s+')[7])
    {
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Seconds 3

    write-host "Creating Topics for Jobs"
    kubectl exec -n $namespace "$kafkapod" -- kafka-topics --bootstrap-server kafka-service:9092 --create --topic jobs
    kubectl exec -n $namespace "$kafkapod" -- kafka-topics --bootstrap-server kafka-service:9092 --create --topic jobs-integration-test

    write-host "Kafka-Broker is now available!"
    write-host "PORT: kubectl port-forward -n $namespace $kafkapod 9092"
    write-host "LOGS: kubectl logs -n $namespace $kafkapod -f"
    while($true)
    {
        Start-Sleep -Seconds 1
    }
}
finally
{
    write-host "Cleaning up..."
    kubectl delete namespace $namespace
    write-host "exited"
}