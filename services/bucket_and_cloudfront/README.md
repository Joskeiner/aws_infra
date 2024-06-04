# S3 y CloudFront

esta es una documentacion que explica el contedido del script
<img align='right' src="[68747470733a2f2f6d656469612e67697068792e636f6d2f6d656469612f54456e586b637348725034596564436868412f67697068792e676966](https://camo.githubusercontent.com/d2ff3eb4e300b4366924419b7894d9fc33842e563f08c74f24eae4b193a4f07e/68747470733a2f2f6d656469612e67697068792e636f6d2f6d656469612f54456e586b637348725034596564436868412f67697068792e676966)" width="230">
## 🚀 Como se estructura el script

este escript tiene la 8 partes las cuales se intenta explicar de forma simple y consisa

**parte 1**

El escript resive dos parametros los cuales se utilizaran para crear el bucket y
subir la carpetas al bucket ,primero se verifica que los parametros son pasados.

```shell
  if [ "$#" -ne 2 ]; then
	echo "Uso: $0 <bucket-name> <local-path>"
	exit 1
fi
```

Si no son pasados el programa saldra con un codigo de error y el mesaje de los parametros que necesita.

Luego se inicializa las variables que se usaran para la configuracion de los servicios

```shell
    BUCKET_NAME="$1"
    LOCAL_PATH="$2"
    ORIGIN_DOMAIN="$BUCKET_NAME.s3.us-east-1.amazonaws.com"
    DEFAULT_ROOT_OBJECT="index.html"


```

**parte 2**

Una vez pasada la primera parte se emite un mensaje donde se le notifica al desarrollador que se esta creado el bucket luego se crea el bucket mediante el cli de aws

```shell
echo "Creando bucket..."

aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1

```

**parte 3**

Ya creado el bucket se configura el mismo para poder habilitar el alogamiento estatico al comando se le pasan la root path donde la pagina se mostrara por defecto y una dirrecion de error en caso del mismo

```shell
echo "Configurando el bucket para alojamiento de sitio web estático..."

aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document error.html

```

**parte 4**

Una vez hecha la configuracion se suben los archivos , **Importante** para que tenga inconvenientes con el la visualizacion del sitio los archivos necesarios para servir la pagina estatica deben estar en la raiz del bucket

```shell
echo "Subiendo los archivos..."

aws s3 sync $LOCAL_PATH s3://$BUCKET_NAME

echo "Bucket $BUCKET_NAME configurado y archivos subidos."

```

**parte 5**

Se creara el origin access control mediante una configuracion pasada en json
si no sabe sobre las (OAC) aqui se deja documentacion sobre el tema link [AWS Docs](https://aws.amazon.com/es/blogs/networking-and-content-delivery/amazon-cloudfront-introduces-origin-access-control-oac/)

```shell
OAC_ID=$(aws cloudfront create-origin-access-control --origin-access-control-config '{
    "Name": "OACFor'$BUCKET_NAME'FROMBASH",
    "Description": "OAC for CloudFront to access S3 bucket",
    "SigningProtocol": "sigv4",
    "SigningBehavior": "always",
    "OriginAccessControlOriginType": "s3"
}' --query 'OriginAccessControl.Id' --output text)


if [ -z "$OAC_ID" ]; then
	echo "ERROR : No se puede crear la Origin Access Control (OAC) de cloudfront"
	exit 1
else
	echo "Origin Access Control ID: $OAC_ID"
	echo "   "
fi


```

**parte 6**

Ya revisado que el OAC se creo correctamente se procede a la creacion de la distribucion de cloudfront el cual se configuracion se pasa por medio de json.

```shell
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

```

**parte 7**

Se verifica que la distribucion haya salido sin problemas y se valida el id de la misma si este id existe , se procede a obtener el arn de la distribucion.

```shell
if [ -z "$DISTRIBUTION_ID" ]; then

	echo "ERROR : No se puede crear la distribution de cloudfront"
	exit 1
else

	CLOUDFRONT_ARN=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query "Distribution.ARN" --output text)

	echo "CloudFront distribution creada con éxito: $DISTRIBUTION_ID"
```

**parte 8**

Actualizacion de las politicas del bucket estas politicas se actualizan para permitir el access al mismo desde cloudfront

```shell

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


```

## Herramienatas y tecnologias usadas

[![My Skills](https://skillicons.dev/icons?i=aws,bash)](https://skillicons.dev)

## Documentacion referente al projecto

[AWS CLI](https://docs.aws.amazon.com/es_es/cli/latest/userguide/getting-started-install.html)

[AWS Docs S3](https://docs.aws.amazon.com/cli/latest/reference/s3api/)

[video youtube](https://www.youtube.com/watch?v=AMJUrGRRv9Y)

[AWS Docs cloudfront](https://docs.aws.amazon.com/cli/latest/reference/cloudfront/)

[Ejemplo de politicas para s3](https://aws.amazon.com/es/blogs/networking-and-content-delivery/amazon-cloudfront-introduces-origin-access-control-oac/)

[Tutorial de aws sobre s3 y sitios web estaticos ](https://docs.aws.amazon.com/es_es/AmazonS3/latest/userguide/HostingWebsiteOnS3Setup.html#step3-add-bucket-policy-make-content-public)


## Autores

- [Joskeiner simosa ](https://www.github.com/octokatherine)

- [Matias Gonzalez](https://github.com/Mat-hub-byte)

- [Agustin ochoa](https://github.com/8agustin)
