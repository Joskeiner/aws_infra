## Cognito

esta es un documento donde se explica el script para correr cognito

**Primero asegurarse de tener todas la dependencias para correr el script**

1.Asegurarse de tener intalado el cli de aws
la version que se usa es la **2.13.5**

```bash
 aws --version
```

2.Asegurarse de tener intalado git

```bash
git --version
```

3.Descargar el repositorio

```bash
git clone https://github.com/Joskeiner/aws_infra.git
```

4.ingresar la carpeta

```bash
cd aws_infra/services/cognito
```

5.correr el script

```bash
sh cognito.sh
```

## Explicacion de Script

Esta explicación se basa en 6 partes, en las cuales cada parte trata de explicar lo que hace cada porción de código.

**parte 1**

Una vez se corra el script, se le deberán pasar 4 datos, los cuales se muestran aquí abajo mediante $1. Si estos datos no son pasados, mostrará un error que indica los valores que necesita para poder funcionar sin problemas.

```shell
GROUP_NAME="$1"
DOMAIN="$2"
APP_CLIENT_NAME="$3"
CALLBACK_URL="$4"
REGION="us-east-1" # Cambia esto si tu región es diferente

  if [ "$#" -ne 4 ]; then
	echo "Uso: $0 <GROUP_NAME> <DOMAIN> <APP_CLIENT_NAME> <CALLBACK_URL>"
	exit 1
fi



```

**parte 2**

Se creará el grupo de usuarios de Cognito donde se especificarán las políticas de clave, los atributos que se deben verificar, el esquema de parámetros a utilizar para iniciar sesión de un usuario y si los usuarios podrán iniciar sesión a voluntad o serán iniciados sesión por un usuario administrador.

```shell
# Crear el grupo de usuarios
USER_POOL_ID=$(aws cognito-idp create-user-pool --pool-name $GROUP_NAME \
	--policies '{
        "PasswordPolicy": {
            "MinimumLength": 8,
            "RequireUppercase": true,
            "RequireLowercase": true,
            "RequireNumbers": true,
            "RequireSymbols": true,
            "TemporaryPasswordValidityDays": 7
        }
    }' \
	--auto-verified-attributes "email" \
	--schema '[
        {
            "Name": "email",
            "AttributeDataType": "String",
            "Required": true,
            "Mutable": false
        }
    ]' \
	--admin-create-user-config '{
        "AllowAdminCreateUserOnly": false
    }' --query 'UserPool.Id' --output text)


```

**parte 3**

Verificamos que el grupo de usuarios haya sido verificado. Si no lo ha sido, emitirá un error.

```shell
  # Verifica si el USER_POOL_ID se obtuvo correctamente
       if [ -z "$USER_POOL_ID" ]; then
         echo "Error creando el User Pool"
         exit 1
       fi


```

**parte 4**

Creamos el dominio. Aquí realizamos la consulta para crear el dominio. Si no hay un error, pasamos a la siguiente instrucción. Si hay un error, verificamos que ese error sea porque el dominio ya está asociado a otro grupo de usuarios. En ese caso, modificamos la variable Domain y le añadimos un timestamp para hacer un dominio único.

```shell
DOMAIN_STATUS=$(aws cognito-idp create-user-pool-domain --domain $DOMAIN --user-pool-id $USER_POOL_ID 2>&1)
if echo "$DOMAIN_STATUS" | grep -q "Domain already associated with another user pool"; then
	echo "El dominio '$DOMAIN' ya está asociado con otro User Pool. Intentando con un dominio alternativo..."
	DOMAIN="${DOMAIN}-$(date +%s)" # Añadir timestamp para hacerlo único
	DOMAIN_STATUS=$(aws cognito-idp create-user-pool-domain --domain $DOMAIN --user-pool-id $USER_POOL_ID)
	if [ $? -ne 0 ]; then
		echo "Error configurando el dominio con un nombre alternativo."
		exit 1
	fi
fi

```

**parte 5**

Creamos el cliente de Cognito y habilitamos el proveedor de identidad de Cognito para el grupo de usuarios. Si usted desea que su inicio de sesión pueda soportar autenticaciones por medios de terceros, actualice el --supported-identity-providers.

Una vez creado, verificamos que no haya habido un error en el proceso.

```shell
CLIENT_ID=$(aws cognito-idp create-user-pool-client --user-pool-id $USER_POOL_ID --client-name $APP_CLIENT_NAME \
	--no-generate-secret \
	--allowed-o-auth-flows "code" "implicit" \
	--allowed-o-auth-scopes "email" "openid" \
	--callback-urls $CALLBACK_URL \
	--supported-identity-providers "COGNITO" \
	--query 'UserPoolClient.ClientId' --output text)

# Verifica si el CLIENT_ID se obtuvo correctamente
if [ -z "$CLIENT_ID" ]; then
	echo "Error creando el cliente de la aplicación"
	exit 1
fi

```

**parte 6**

En esta parte se configura el grupo de usuarios para que pueda recuperar la cuenta mediante correo electrónico.

```shell
aws cognito-idp update-user-pool --user-pool-id $USER_POOL_ID \
	--account-recovery-setting '{
       "RecoveryMechanisms": [
          {
             "Priority": 1,
             "Name": "verified_email"
          }
       ]
    }'



```

## Tecnologias y herramientas usadas

**Herramienatas y tecnologias usadas**

[![My Skills](https://skillicons.dev/icons?i=aws,bash)](https://skillicons.dev)

## Documentacion referente al projecto

[AWS CLI](https://docs.aws.amazon.com/es_es/cli/latest/userguide/getting-started-install.html)

[Bash](https://soloconlinux.org.es/scripts-en-bash/)

[video youtube](https://www.youtube.com/watch?v=n3br_TzJW28)

[AWS Docs cognito](https://docs.aws.amazon.com/cli/latest/reference/cognito-idp/)

## Autores

- [Joskeiner simosa ](https://www.github.com/octokatherine)

- [Matias Gonzalez](https://github.com/Mat-hub-byte)

- [Agustin ochoa](https://github.com/8agustin)
