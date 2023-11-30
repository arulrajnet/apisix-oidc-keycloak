#! /usr/bin/env sh
set -e
# set -x

export APISIX_SERVICE_HOST=${APISIX_SERVICE_HOST:-apisix}
export APISIX_SERVICE_ADMIN_PORT=${APISIX_SERVICE_ADMIN_PORT:-9180}
export APISIX_SERVICE_ADMIN_SECRET=${APISIX_SERVICE_ADMIN_SECRET:-topsecret}
CURL_OPTS="--silent --show-error --fail"
# CURL_OPTS="-v"

# Delete

## routes
routes=$(curl $CURL_OPTS -X GET -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/routes | jq -r '.list[]|.value.id')

for route in $routes; do
  curl $CURL_OPTS -X DELETE -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/routes/$route
done

## services
services=$(curl $CURL_OPTS -X GET -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/services | jq -r '.list[]|.value.id')

for service in $services; do
  curl $CURL_OPTS -X DELETE -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/services/$service
done

# Create

## service

### Keycloak

curl $CURL_OPTS -X PUT -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/services/1 -d '
{
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "keycloak:8080": 1
        }
    }
}'

### Whoami

curl $CURL_OPTS -X PUT -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/services/2 -d '
{
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "whoami:80": 1
        }
    }
}'


## routes

### Keycloak

curl $CURL_OPTS -X PUT -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/routes/11 -d "
{
    \"uris\": [\"/auth/*\", \"/auth/\"],
    \"service_id\": \"1\",
    \"hosts\": [\"*.${BASE_FQDN}\"],
    \"methods\": [\"GET\",\"POST\",\"PUT\",\"DELETE\"],
    \"priority\": 999
}"

### Whoami

curl $CURL_OPTS -X PUT -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/routes/12 -d "
{
    \"uris\": [\"/whoami/*\", \"/\"],
    \"service_id\": \"2\",
    \"hosts\": [\"foo.${BASE_FQDN}\"],
    \"methods\": [\"GET\",\"POST\",\"PUT\",\"DELETE\"],
    \"priority\": 10,
    \"plugins\":{
        \"openid-connect\":{
            \"client_id\": \"foo\",
            \"client_secret\": \"${FOO_CLIENT_SECRET}\",
            \"discovery\": \"http://foo.${BASE_FQDN}/auth/realms/foo/.well-known/openid-configuration\",
            \"scope\": \"openid profile\",
            \"bearer_only\": false,
            \"realm\": \"foo\",
            \"introspection_endpoint_auth_method\": \"client_secret_post\",
            \"redirect_uri\": \"http://foo.${BASE_FQDN}/\",
            \"logout_path\": \"/whoami/logout\",
            \"post_logout_redirect_uri\": \"http://foo.${BASE_FQDN}/whoami/\"
        }
    }
}"

curl $CURL_OPTS -X PUT -H "X-API-KEY: ${APISIX_SERVICE_ADMIN_SECRET}" http://${APISIX_SERVICE_HOST}:${APISIX_SERVICE_ADMIN_PORT}/apisix/admin/routes/13 -d "
{
    \"uris\": [\"/whoami/*\", \"/\"],
    \"service_id\": \"2\",
    \"hosts\": [\"bar.${BASE_FQDN}\"],
    \"methods\": [\"GET\",\"POST\",\"PUT\",\"DELETE\"],
    \"priority\": 10,
    \"plugins\":{
        \"openid-connect\":{
            \"client_id\": \"bar\",
            \"client_secret\": \"${BAR_CLIENT_SECRET}\",
            \"discovery\": \"http://bar.${BASE_FQDN}/auth/realms/bar/.well-known/openid-configuration\",
            \"scope\": \"openid profile\",
            \"bearer_only\": false,
            \"realm\": \"bar\",
            \"introspection_endpoint_auth_method\": \"client_secret_post\",
            \"redirect_uri\": \"http://bar.${BASE_FQDN}/\",
            \"logout_path\": \"/whoami/logout\",
            \"post_logout_redirect_uri\": \"http://foo.${BASE_FQDN}/whoami/\"
        }
    }
}"
