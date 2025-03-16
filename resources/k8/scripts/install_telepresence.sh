helm repo add datawire https://getambassador.io
helm repo update datawire
helm install traffic-manager -n ambassador datawire/telepresence --namespace $NAMESPACE

# TODO: Can't figure out how to get this working within the docker container yet.
# telepresence helm install --namespace $NAMESPACE