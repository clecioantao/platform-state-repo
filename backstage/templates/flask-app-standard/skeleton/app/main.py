from flask import Flask

app = Flask(__name__)

@app.get("/")
def hello():
    return {"app": "${{ values.component_id }}", "status": "ok"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
