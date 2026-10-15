// Publica en Pub/Sub por REST con el token de la SA del servicio (servidor de metadatos), sin claves.
const metadataToken = async () => {
  const r = await fetch(
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
    { headers: { "Metadata-Flavor": "Google" } },
  );
  if (!r.ok) throw new Error(`metadata ${r.status}`);
  return (await r.json()).access_token;
};

export const publish = async (topic, data, attributes = {}) => {
  const name = topic.startsWith("projects/") ? topic : `projects/${process.env.GOOGLE_CLOUD_PROJECT}/topics/${topic}`;
  const r = await fetch(`https://pubsub.googleapis.com/v1/${name}:publish`, {
    method: "POST",
    headers: { authorization: `Bearer ${await metadataToken()}`, "content-type": "application/json" },
    body: JSON.stringify({ messages: [{ data: Buffer.from(JSON.stringify(data)).toString("base64"), attributes }] }),
  });
  if (!r.ok) throw new Error(`pubsub ${r.status}: ${await r.text()}`);
  return (await r.json()).messageIds[0];
};
