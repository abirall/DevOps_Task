from flask import Flask, render_template
import psutil
import platform
from datetime import datetime

app = Flask(__name__)

def get_system_info():
    return {
        "cpu_usage": psutil.cpu_percent(interval=1),
        "memory_usage": psutil.virtual_memory().percent,
        "disk_usage": psutil.disk_usage('/').percent,
        "platform": platform.system(),
        "platform_version": platform.version(),
        "architecture": platform.machine(),
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }

@app.route("/")
def index():
    system_info = get_system_info()
    return render_template("index.html", info=system_info)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
