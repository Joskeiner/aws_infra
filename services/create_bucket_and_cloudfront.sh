#https://repost.aws/es/knowledge-center/s3-troubleshoot-403

#!/bin/bash
#verificamos que se alla enviando los argumentos para poder
#crear el bucket y su configuraciones
# Verificar si los argumentos son suficientes
if [ "$#" -ne 2 ]; then
	echo "Uso: $0 <bucket-name> <local-path>"
	exit 1
fi

#el $ y numero indica la forma en la que instanciara las Variables en el script
# Variables configurables
BUCKET_NAME="$1"
LOCAL_PATH="$2"
ORIGIN_DOMAIN="$BUCKET_NAME.s3.us-east-1.amazonaws.com"
DEFAULT_ROOT_OBJECT="index.html"

# Clonar repositorio (si es necesario)
# git clone https://github.com/Joskeiner/chess-master.git
# cd chess-master/

echo "Creando bucket..."
# Crear el bucket de S3
aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1

echo "Configurando el bucket para alojamiento de sitio web estático..."
# Configuración del bucket para alojamiento de sitio web estático
aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document error.html

echo "Subiendo los archivos..."
# Subiendo carpetas de producción
aws s3 sync $LOCAL_PATH s3://$BUCKET_NAME

echo "Bucket $BUCKET_NAME configurado y archivos subidos."
echo " "
echo "Creando el Origin Access Control (OAC)..."
# Crear el Origin Access Control (OAC)
OAC_ID=$(aws cloudfront create-origin-access-control --origin-access-control-config '{
    "Name": "OACFor'$BUCKET_NAME'FROMBASH",
    "Description": "OAC for CloudFront to access S3 bucket",
    "SigningProtocol": "sigv4",
    "SigningBehavior": "always",
    "OriginAccessControlOriginType": "s3"
}' --query 'OriginAccessControl.Id' --output text)
#verificar y mostrar el arn obtenido
if [ -z "$OAC_ID" ]; then
	echo "ERROR : No se puede crear la Origin Access Control (OAC) de cloudfront"
	exit 1
else
	echo "Origin Access Control ID: $OAC_ID"
	echo "   "
fi
echo "Creando la distribución de CloudFront..."
# Crear la distribución de CloudFront
DISTRIBUTION_ID=$(aws cloudfront create-distribution --distribution-config '{
    "CallerReference": "'$(date +%s)'",
    "Comment": "Distribution for '$BUCKET_NAME'",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "'$BUCKET_NAME'",
                "DomainName": "'$ORIGIN_DOMAIN'",
                "OriginAccessControlId": "'$OAC_ID'",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "'$BUCKET_NAME'",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "Compress": true,
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000
    },
    "Enabled": true,
    "DefaultRootObject": "'$DEFAULT_ROOT_OBJECT'",
    "ViewerCertificate": {
        "CloudFrontDefaultCertificate": true
    }
}' --query 'Distribution.Id' --output text)

# Verificar y mostrar el ARN obtenido
if [ -z "$DISTRIBUTION_ID" ]; then

	echo "ERROR : No se puede crear la distribution de cloudfront"
	exit 1
else

	CLOUDFRONT_ARN=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query "Distribution.ARN" --output text)

	#echo "El ARN de la distribución es: $CLOUDFRONT_ARN"
	echo "  "
	echo "CloudFront distribution creada con éxito: $DISTRIBUTION_ID"

	echo "  "
	echo "Configurando políticas del bucket..."
	# Aplicando políticas al bucket
	aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "'$CLOUDFRONT_ARN'"
                }
            }
        }
    ]
}'
fi

echo "las politicas se actualizaron con exito  "
echo "  "
echo "==========================================================="
echo "IMPORTANTE : La distribución de cloudfront se creo sin"
echo "proteccion WAF recuerde habilitarla en las configuraciones"
echo "de de seguridad de cloudfront : $DISTRIBUTION_ID"
echo "==========================================================="
