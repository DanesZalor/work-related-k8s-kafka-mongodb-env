param(
    [Parameter(Position=0,Mandatory=$true)][string] $namespace,
    [Parameter(Position=0,Mandatory=$true)][string[]] $topics
)

$env:KIND_EXPERIMENTAL_PROVIDER="podman"
$OUTPUT = "outputfile.yaml"

function createBIGYAML
{
    if(Test-Path $OUTPUT)
    {
        Remove-Item $OUTPUT
    }
    
    New-Item $OUTPUT

    $yamlfilesToUse = $(ls .\*.yml) + $(ls .\kubernetes-mongodb\*.yml);

    foreach($file in $yamlfilesToUse)
    {
        Write-Output $(Get-Content $file) "---" >> $OUTPUT;
    }

    Write-Output $($(Get-Content $OUTPUT) -replace "reserved-word-for-namespace-123456789", $namespace)  > $OUTPUT;
    kubectl apply -f $OUTPUT;
}

try
{
    Write-Output "Creating Kafka K8 resources"
    
    if($($($(kubectl get namespaces) -match $namespace) -split '\s+').length -ne 0)
    {
        write-host "Detected uncleaned Kafka K8 resources. Deleting..."
        kubectl delete namespace $namespace
    }
    
    write-host "Setting up K8 Resources..."
    createBIGYAML($namespace);

    Start-Sleep 1 # wait for the kafkapod to be Up and Running

    write-host "Waiting for Kafka Broker to start..."
    $kafkapod = (kubectl get pods -n $namespace | findstr kafka).Split()[0]

    for($status = ""; $status -ne "Running"; $status = $($(kubectl get pods -n $namespace $kafkapod) -split '\s+')[7])
    {
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Seconds 3

    write-host "Creating Topics for Jobs"
    foreach($topic in $topics)
    {
        kubectl exec -n $namespace "$kafkapod" -- kafka-topics --bootstrap-server kafka-service:9092 --create --topic $topic
    }

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
    if(Test-Path $OUTPUT)
    {
        Remove-Item $OUTPUT
    }
    kubectl delete namespace $namespace
    write-host "exited"
}