from fastapi import FastAPI, Request
from google.cloud import aiplatform
from google.cloud.aiplatform_v1.models import Endpoint

app = FastAPI()

# Initialize AI Platform client
client = aiplatform.gapic.EndpointServiceClient()

# Replace with your Endpoint ID
endpoint_id = "YOUR_ENDPOINT_ID"

# Get Endpoint details
endpoint = client.get_endpoint(name=endpoint_id)

# Define context 
context = "This is additional context for your question."

@app.post("/ask")
async def ask(request: Request):
    try:
        data = await request.json()
        question = data.get("question")

        if not question:
            return {"error": "Question is required"}

        # Combine question and context
        prompt = f"{context}\n\n{question}"

        # Prepare request for LLM
        request = {
            "instances": [{"content": prompt}]
        }

        # Make prediction
        response = endpoint.predict(request=request)

        return {"answer": response.predictions[0]["content"]}

    except Exception as e:
        return {"error": str(e)}
