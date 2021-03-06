printf "\n"
printf "\033[1mInstalling k8s operators\n"
printf -- "------------------------\033[0m\n"
kubectl create -f https://github.com/minio/minio-operator/blob/1.0.7/minio-operator.yaml?raw=true --validate=false
#helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com/
#kubectl create ns kafka
#helm install kafka-operator --namespace=kafka banzaicloud-stable/kafka-operator
#kubectl create ns zookeeper
#helm install zookeeper-operator --namespace=zookeeper banzaicloud-stable/zookeeper-operator
# Cassandra operator does not have helm chart yet
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
kubectl create ns cassandra
kubectl -n cassandra apply -f https://raw.githubusercontent.com/instaclustr/cassandra-operator/v3.1.1/deploy/crds.yaml
kubectl -n cassandra apply -f https://raw.githubusercontent.com/instaclustr/cassandra-operator/v3.1.1/deploy/bundle.yaml
kubectl -n cassandra delete cm cassandra-operator-default-config && \

printf "\n"
printf "\033[1mInstalling cert-manager\n"
printf -- "------------------------\033[0m\n"
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager.yaml
printf "\033[1mWaiting for cert-manager web-hook to come up\033[0m\n"
while [ -z "$(kubectl -n cert-manager get pods -l=app=webhook --ignore-not-found)" ]; do
  printf "."; sleep 5;
done
while kubectl -n cert-manager get pods -l=app=webhook -o jsonpath="{.items[*].status.containerStatuses[*].ready}" | grep false >> /dev/null; do
  printf "."; sleep 5;
done;
printf "\033[1m\nCert-manager Webhook ready! Now applying clusterissuer for self-cert.\033[0m\n"
kubectl apply -f ../kubernetes/cert-manager/clusterissuer-self-cert.yaml
printf -- "\033[1mOperators installed successfully.\033[0m\n"
