param(
    [Parameter(Position=1,Mandatory=$true)][string[]] $topics
)

$env:KIND_EXPERIMENTAL_PROVIDER="podman"

try
{
    write-host "Cleaning up"
    if($(kubectl get all --selector=appGroup=local-cluster-setup).Count -ne 0)
    {
        kubectl delete -k .
    }

    for($ready = $False; -Not $ready; $ready = $(kubectl get all --selector=appGroup=local-cluster-setup).Count -eq 0)
    {
        Start-Sleep 1;
    }

    podman start kind-control-plane
    Write-Output "Creating Kafka K8 resources"
    kubectl apply -k .

    Start-Sleep 1 # wait for the kafkapod to be Up and Running

    write-host "Waiting for Kafka Broker to start..."
    $kafkapod = $(kubectl get pods -l=app=kafka-broker)[1].Split()[0]

    for($ready = $False; -Not $ready; $ready = $(kubectl get pods $kafkapod)[1] -match '1/1')
    {
        Start-Sleep -Seconds 1
    }

    Start-Sleep -Seconds 1

    write-host "Creating Topics for Jobs"
    foreach($topic in $topics)
    {
        kubectl exec "$kafkapod" -- kafka-topics --bootstrap-server kafka-service:9092 --create --topic $topic
    }

    write-host "Kafka-Broker and Mongo DB is now available!"
    write-host "Useful commands"
    write-host "[port-forward]: kubectl port-forward $kafkapod 9092"
    write-host "[kafka-console-consumer]: kubectl exec $kafkapod -- kafka-console-consumer --bootstrap-server kafka-service:9092 --topic <topic>"
    write-host "[monitor] kubectl get all --selector=appGroup=local-cluster-setup"
    
    while($true)
    {
        Start-Sleep -Seconds 1
    }
}
finally
{
    write-host "Cleaning up..."
    kubectl delete -k .
}