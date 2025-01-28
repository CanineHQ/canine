# This needs to be on the canine server to work (assuming linux)

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install helm
sudo curl -fsSLo get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod a+x get_helm.sh
sudo ./get_helm.sh

# Install telepresence
sudo curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.21.1/telepresence-linux-amd64 -o /usr/local/bin/telepresence
sudo chmod a+x /usr/local/bin/telepresence
