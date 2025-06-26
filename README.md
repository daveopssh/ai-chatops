# AI Chat API

Nota: Esto fue generado con Google Gemini CLI :) 

Este proyecto es una API de chat construida con FastAPI que utiliza un almacén de vectores para proporcionar respuestas basadas en IA. La infraestructura se gestiona con Terraform y la base de datos vectorial se ejecuta en un contenedor Docker.

## Primeros Pasos

Estas instrucciones te permitirán tener una copia del proyecto en funcionamiento en tu máquina local para desarrollo y pruebas.

### Prerrequisitos

Necesitarás tener instalado lo siguiente en tu sistema:

*   [Python 3.13](https://www.python.org/)
*   [uv](https://github.com/astral-sh/uv)
*   [Docker](https://www.docker.com/)
*   [Terraform](https://www.terraform.io/)
*   [AWS CLI](https://aws.amazon.com/cli/)

### Instalación

1.  **Clona el repositorio:**

    ```bash
    git clone <url-del-repositorio>
    cd openai-pp
    ```

2.  **Crea un entorno virtual e instala las dependencias:**

    ```bash
    python -m venv .venv
    source .venv/bin/activate
    uv pip install -r requirements.txt
    ```

### Ejecutando la Aplicación

1.  **Construye la imagen de Docker:**

    ```bash
    docker build -t openai-pp .
    ```

2.  **Inicia la base de datos vectorial:**

    El proyecto utiliza un script para iniciar una base de datos PostgreSQL con la extensión `pgvector` en un contenedor Docker.

    ```bash
    ./script/db.sh start
    ```

3.  **Inicia la aplicación FastAPI:**

    Una vez que la base de datos esté en funcionamiento, puedes iniciar la aplicación:

    ```bash
    uvicorn main:app --reload
    ```

    La API estará disponible en `http://127.0.0.1:8000`.

## Uso

La API expone los siguientes endpoints:

*   `GET /`: Endpoint de verificación de estado. Devuelve `"Ok"` si la aplicación está en funcionamiento.
*   `POST /chat`: Endpoint principal del chat.

    **Payload:**

    ```json
    {
      "chat": "Tu mensaje aquí"
    }
    ```

    **Respuesta:**

    ```json
    {
      "response": "La respuesta de la IA"
    }
    ```

## Infraestructura

La infraestructura del proyecto se gestiona con Terraform. Los archivos de configuración se encuentran en el directorio `.infra/`.

Para desplegar la infraestructura, navega al directorio `.infra` y ejecuta:

```bash
terraform init
terraform apply
```

## Scripts

*   `script/db.sh`: Un script de utilidad para gestionar el ciclo de vida del contenedor de la base de datos.

    *   `./script/db.sh start`: Inicia el contenedor de la base de datos.
    *   `./script/db.sh stop`: Detiene el contenedor de la base de datos.
