#!/bin/bash

# Variables configurables
GROUP_NAME="chessmasterDefault"
DOMAIN="chessmaster"
APP_CLIENT_NAME="chessmasterIFts"
CALLBACK_URL="https://jwt.io"

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

# Verifica si el USER_POOL_ID se obtuvo correctamente
if [ -z "$USER_POOL_ID" ]; then
	echo "Error creando el User Pool"
	exit 1
fi

# Configurar el dominio
aws cognito-idp create-user-pool-domain --domain $DOMAIN --user-pool-id $USER_POOL_ID

# Crear el cliente de la aplicación
CLIENT_ID=$(aws cognito-idp create-user-pool-client --user-pool-id $USER_POOL_ID --client-name $APP_CLIENT_NAME \
	--no-generate-secret \
	--allowed-o-auth-flows "code" "implicit" \
	--allowed-o-auth-scopes "email" "openid" \
	--callback-urls $CALLBACK_URL \
	--query 'UserPoolClient.ClientId' --output text)

# Verifica si el CLIENT_ID se obtuvo correctamente
if [ -z "$CLIENT_ID" ]; then
	echo "Error creando el cliente de la aplicación"
	exit 1
fi

#Configurar la recuperación de cuenta
aws cognito-idp update-user-pool --user-pool-id $USER_POOL_ID \
	--account-recovery-setting '{
       "RecoveryMechanisms": [
          {
             "Priority": 1,
            "Name": "verified_email"
        }
   ]
}'

# Imprimir detalles
echo "###########################################################################################################################################*"
echo "*    Cognito User Pool creado con ID: $USER_POOL_ID                                                                                        "
echo "*                                                                                                                                          "
echo "*    Dominio de Cognito configurado: https://$DOMAIN.auth.us-east-1.amazoncognito.com                                                      "
echo "*                                                                                                                                           "
echo "*    ID del cliente de la aplicación Cognito: $CLIENT_ID                                                                                   "
echo "*                                                                                                                                          "
# Instrucciones adicionales para el usuario
echo "*    Para usar la UI alojada de Cognito, dirígete a la siguiente URL:                                                                      "
echo "*                                                                                                                                          "
echo "*    https://$DOMAIN.auth.us-east-1.amazoncognito.com/oauth2/authorize?response_type=token&client_id=$CLIENT_ID&redirect_uri=$CALLBACK_URL "
echo "############################################################################################################################################*"
