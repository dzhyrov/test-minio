import os
from kubernetes import client, config
import base64
import sys
import yaml

dex_config_secret_name = "dex-config-secret"
dex_config_secret_namespace = "auth"
dex_config_secret_bind_pw = "AUTH_SECRET_BIND_PW"

auth_secret_name = os.environ["AUTH_SECRET_NAME"] if "AUTH_SECRET_NAME" in os.environ and os.environ["AUTH_SECRET_NAME"] else "hpecp-ext-auth-secret"
auth_secret_namespace = os.environ["AUTH_SECRET_NAMESPACE"] if "AUTH_SECRET_NAMESPACE" in os.environ and os.environ["AUTH_SECRET_NAMESPACE"] else "hpecp"
auth_secret_bind_pw = ''

__location__ = os.path.realpath(
    os.path.join(os.getcwd(), os.path.dirname(__file__)))
dex_template_location = os.path.join(__location__, "template.yaml")

def b64decode(source : str) -> str:
    return base64.b64decode(source.encode('ascii')).decode('ascii')

def b64encode(source : str) -> str:
    return base64.b64encode(source.encode('ascii')).decode('ascii')

def get_group_search_configured(connector : dict):
    print("Preparing groups search settings...")
    group = secret.data.get("groups")

    if not group:
        print("Group search settings cofigured!")
        return config
    connector['config']['groupSearch'] = {}

    group = b64decode(group)

    group_filter = ""
    group_base_dn = "none"

    if "::::" in group:
        #for multiple group that are separeted by ::::

        groups = group.split("::::")

        #fetching group base dn and verifing that all groups have the same base dn (restriction of dex)
        for one_of_groups in groups:
            group_root_dn = one_of_groups.split(",")[1]
            if group_root_dn != "none":
                group_base_dn=group_root_dn
                break

        #creating filter from first parameter in groups dn
        group_filter = "\"(|"
        for one_of_groups in groups:
            group_cn = one_of_groups.split(",")[0]
            group_filter = group_filter + "(" + group_cn + ")"
        group_filter += ")\""

    else:
        #for single group
        group_filter = "\"(" + group.split(",")[0] + ")\""
        group_base_dn = group.split(",")[1]

    connector['config']['groupSearch']['baseDN'] = group_base_dn
    connector['config']['groupSearch']['filter'] = group_filter
    connector['config']['groupSearch']['nameAttr'] = ''

    print("Group search settings cofigured!")

def get_user_search_configured(connector : dict):
    print("Preparing user search settings...")

    user_base_dn = secret.data.get("base_dn")
    if not user_base_dn:
        sys.exit("[ERROR]   'base_dn' is not found in secret")
    user_base_dn=b64decode(user_base_dn)

    username=secret.data.get("user_attr")
    if not username:
        sys.exit("[ERROR]   'user_attr' is not found in secret")
    username=base64.b64decode(username.encode('ascii')).decode('ascii')

    connector['config']['userSearch']['baseDN'] = user_base_dn
    connector['config']['userSearch']['username'] = username
    connector['config']['userSearch']['nameAttr'] = username

    print("User search settings cofigured!")

def get_security_configured(connector : dict, auth_type_info):
    print("Preparing security settings...")

    if auth_type_info['security_protocol'] == "none":
        connector['config']['startTLS'] = False
        connector['config']['insecureNoSSL'] = True
        connector['config']['insecureSkipVerify'] = True

        print("Security settings cofigured!")
        return

    connector['config']['insecureNoSSL'] = False

    root_ca_data = secret.data.get("ca_cert")
    
    if not root_ca_data:
        connector['config']['insecureSkipVerify'] = True
    else:
        connector['config']['insecureSkipVerify'] = False
        connector['config']['rootCAData'] = root_ca_data

    if auth_type_info['security_protocol'] == "ldaps":
        connector['config']['startTLS'] = False
    elif auth_type_info['security_protocol'] == "starttls":
        connector['config']['startTLS'] = True

    print("Security settings cofigured!")

def get_bind_configured(connector: dict, auth_type_info) -> str:
    print("Preparing bind settings...")

    if auth_type_info['bind_type'] != "search_bind":
        sys.exit("[ERROR]    Bind type: '$bind_type' is not supported.")

    bind_dn = secret.data.get("bind_dn")

    #anonymous search bind
    if not bind_dn:
        return

    bind_dn = b64decode(bind_dn)

    bind_pw = secret.data.get("bind_pwd")
    
    if not bind_pw:
        sys.exit("[ERROR]   'bind_pwd' is not found in secret")
    
    bind_pw = b64decode(bind_pw)
    connector['config']['bindDN'] = bind_dn
    connector['config']['bindPW'] = '$' + dex_config_secret_bind_pw

    global auth_secret_bind_pw
    auth_secret_bind_pw = bind_pw

    print("Bind settings cofigured!")

def get_host_configured(connector : dict):
    print("Preparing host settings...")

    host = secret.data.get("auth_service_locations")

    if not host:
        sys.exit("[ERROR]   'auth_service_locations' is not found in secret")
    
    connector['config']['host'] = b64decode(host)

    print("Host settings cofigured!")

def get_connector_for_ldap(auth_type_info) -> dict:
    print("Preparing config for LDAP...")

    connector = {}

    connector['id'] = "ldap"
    connector['name'] = "LDAP"
    connector['type'] = "ldap"
    connector['config'] = {}
    connector['config']['userSearch'] = {}
    connector['config']['userSearch']['idAttr'] = 'uid'
    connector['config']['userSearch']['emailAttr'] = 'uid'

    get_host_configured(connector)
    get_bind_configured(connector, auth_type_info)
    get_security_configured(connector, auth_type_info)
    get_user_search_configured(connector)
    get_group_search_configured(connector)

    return connector

def get_connector_for_ad(auth_type_info) -> dict:
    print("Preparing config for Active Directory...")

    connector = {}
    
    connector['id'] = "ad"
    connector['name'] = "ActiveDirectory"
    connector['type'] = "ldap"
    connector['config'] = {}
    connector['config']['userSearch'] = {}
    connector['config']['userSearch']['idAttr'] = 'DN'
    connector['config']['userSearch']['emailAttr'] = 'cn'

    get_host_configured(connector)
    get_bind_configured(connector, auth_type_info)
    get_security_configured(connector, auth_type_info)
    get_user_search_configured(connector)
    get_group_search_configured(connector)

    return connector

def get_auth_type_info():
    print("Defining auth type...")

    directory_server = secret.data.get("type")
    if not directory_server:
        sys.exit("[ERROR]   'type' is not found in secret")
    directory_server=b64decode(directory_server)

    security_protocol = secret.data.get("security_protocol")
    if not security_protocol:
        sys.exit("[ERROR]   'security_protocol' is not found in secret")
    security_protocol=b64decode(security_protocol)

    bind_type = secret.data.get("bind_type")
    if not bind_type:
        sys.exit("[ERROR]   'bind_type' is not found in secret")
    bind_type=b64decode(bind_type)
    
    auth_type_info = {}
    
    auth_type_info['directory_server'] = directory_server
    auth_type_info['security_protocol'] = security_protocol
    auth_type_info['bind_type'] = bind_type

    return auth_type_info

try:
    config.load_kube_config()
except:
    # load_kube_config throws if there is no config, but does not document what it throws, so I can't rely on any particular type here
    config.load_incluster_config()

v1 = client.CoreV1Api()

with open(dex_template_location, 'r') as template:
    config = yaml.safe_load(template)

print("Reading secret", auth_secret_name, "from namespace", auth_secret_namespace)
try:
    secret = v1.read_namespaced_secret(name = auth_secret_name, namespace = auth_secret_namespace)
    auth_type_info = get_auth_type_info()

    if auth_type_info['security_protocol'] == "none":
        print("Found settings for", auth_type_info['directory_server'], "without security connection and bind type:", auth_type_info['bind_type'])
    else:
        print("Found settings for", auth_type_info['directory_server'], "with connection:", auth_type_info['security_protocol'], "and bind type:", auth_type_info['bind_type'])

    connector = {}
    if auth_type_info['directory_server'] == "LDAP":
        connector = get_connector_for_ldap(auth_type_info)
    elif auth_type_info['directory_server'] == "Active Directory":
        connector = get_connector_for_ad(auth_type_info)
    else:
        raise Exception('Unsupported directory server')

    config['connectors'] = [connector]
except client.exceptions.ApiException as err:
    if err.status != 404:
        print("Unexpected error while connecting to kubernetes")
        sys.exit(err)
    else:
        print("Secret was not found. Kubeflow will be configured without authentication.")
        config['enablePasswordDB'] = True
        staticPasswords = {
            'email' : "admin@kubeflow.org",
            'hash' : "$2y$12$ruoM7FqXrpVgaol44eRZW.4HWS8SAvg6KYVVSCIwKQPBmTpCm.EeO",
            'username' : 'admin',
            'userID' : '08a8684b-db88-4b73-90a9-3cd1661f5466'
        }
        config['staticPasswords'] = [staticPasswords]

print("Config created! Setting up it to config map...")

try:
    secret = v1.read_namespaced_secret(name = dex_config_secret_name, namespace = dex_config_secret_namespace)
    raise Exception('Dex config secret already exists!')
except client.exceptions.ApiException as err:
    if err.status != 404:
        print("Unexpected error while connecting to kubernetes")
        sys.exit(err)

v1.create_namespaced_secret(
    namespace=dex_config_secret_namespace,
    body=client.V1Secret(
        metadata=client.V1ObjectMeta(
            name=dex_config_secret_name,
        ),
        type="Opaque",
        data={
            "config.yaml" : b64encode(yaml.dump(config)),
            "AUTH_SECRET_BIND_PW" : b64encode(auth_secret_bind_pw)
        },
    )
)

print("Success!")
