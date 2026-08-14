"""Backend Model Manager — docs/BUILD_PLAN.md §4 lifecycle on the server side.

Discover → Download → Verify (SHA-256) → Install (into local cache) → Load
→ Report. The canonical registry is models/registry.yaml at the repo root;
weights live in backend/.model_cache/ (gitignored, never committed).
"""

import hashlib
import urllib.request
from pathlib import Path

import yaml

REGISTRY_PATH = Path(__file__).resolve().parents[3] / "models" / "registry.yaml"
CACHE_DIR = Path(__file__).resolve().parents[2] / ".model_cache"

REQUIRED_FIELDS = [
    "name", "github", "revision", "license", "weights", "checksum",
    "runtime", "task", "hardware", "installed", "tested", "notes",
]


class RegistryEntryError(Exception):
    pass


class ModelManager:
    def __init__(self) -> None:
        self._registry: dict[str, dict] = {}
        self._loaded: dict[str, object] = {}

    # -- Discover ----------------------------------------------------------
    def discover(self) -> None:
        doc = yaml.safe_load(REGISTRY_PATH.read_text())
        entries = {}
        for entry in doc.get("models") or []:
            missing = [f for f in REQUIRED_FIELDS if f not in entry]
            if missing:
                raise RegistryEntryError(
                    f"Registry entry '{entry.get('name', '<unnamed>')}' is missing "
                    f"required fields: {', '.join(missing)}. No placeholder values."
                )
            entries[entry["name"]] = entry
        self._registry = entries

    # -- Verify / Install --------------------------------------------------
    def cache_path(self, name: str) -> Path:
        return CACHE_DIR / (name + Path(self._registry[name]["weights"]).suffix)

    def verify(self, name: str) -> bool:
        path = self.cache_path(name)
        if not path.exists():
            return False
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        return digest == self._registry[name]["checksum"]

    def download(self, name: str) -> None:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        url = self._registry[name]["weights"]
        with urllib.request.urlopen(url, timeout=300) as resp:
            data = resp.read()
        if hashlib.sha256(data).hexdigest() != self._registry[name]["checksum"]:
            raise RegistryEntryError(
                f"Downloaded weights for '{name}' failed checksum verification. "
                "Nothing was installed."
            )
        self.cache_path(name).write_bytes(data)

    def ensure_ready(self, name: str) -> Path:
        if name not in self._registry:
            raise KeyError(f"Model '{name}' is not registered.")
        if not self.verify(name):
            self.download(name)
            if not self.verify(name):
                raise RegistryEntryError(f"Model '{name}' could not be verified.")
        return self.cache_path(name)

    # -- Load --------------------------------------------------------------
    def load(self, name: str, factory):
        if name not in self._loaded:
            path = self.ensure_ready(name)
            self._loaded[name] = factory(str(path))
        return self._loaded[name]

    # -- Report ------------------------------------------------------------
    def report(self) -> list[dict]:
        return [
            {
                "name": e["name"],
                "task": e["task"],
                "runtime": e["runtime"],
                "hardware": e["hardware"],
                "license": e["license"],
                "installed": self.verify(e["name"]),
                "loaded": e["name"] in self._loaded,
            }
            for e in self._registry.values()
        ]


manager = ModelManager()
