self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting())
})

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("push", (event) => {
  const data = readPushData(event)
  const title = data.title || "Removlo update"

  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || "You have a new activity update.",
      icon: data.icon || "/icon.svg",
      badge: data.badge || "/icon.svg",
      tag: data.tag || data.notification_id || "removlo-notification",
      renotify: true,
      timestamp: data.timestamp || Date.now(),
      requireInteraction: data.require_interaction || false,
      actions: data.actions || [{ action: "open", title: "Open" }],
      data: {
        url: data.url || "/dashboard",
        notification_id: data.notification_id,
        event_type: data.event_type
      }
    })
  )
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = safeClientUrl(event.notification.data?.url || "/dashboard")

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ("focus" in client && "navigate" in client) {
          client.navigate(url)
          return client.focus()
        }
      }

      return clients.openWindow(url)
    })
  )
})

self.addEventListener("pushsubscriptionchange", (event) => {
  event.waitUntil(resubscribe(event.oldSubscription))
})

function readPushData(event) {
  if (!event.data) return {}

  try {
    return event.data.json()
  } catch (_error) {
    return { body: event.data.text() }
  }
}

function safeClientUrl(url) {
  try {
    const parsed = new URL(url, self.location.origin)
    if (parsed.origin !== self.location.origin) return "/dashboard"
    return `${parsed.pathname}${parsed.search}${parsed.hash}`
  } catch (_error) {
    return "/dashboard"
  }
}

async function resubscribe(oldSubscription) {
  const configResponse = await fetch("/web_push/config", {
    credentials: "same-origin",
    headers: { "Accept": "application/json" }
  })
  if (!configResponse.ok) return

  const config = await configResponse.json()
  if (!config.enabled || !config.public_key) return

  if (oldSubscription) {
    await fetch("/web_push_subscription", {
      method: "DELETE",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ endpoint: oldSubscription.endpoint })
    })
  }

  const newSubscription = await self.registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(config.public_key)
  })

  await fetch("/web_push_subscription", {
    method: "POST",
    credentials: "same-origin",
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ subscription: newSubscription.toJSON() })
  })
}

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const rawData = atob(base64)
  const outputArray = new Uint8Array(rawData.length)

  for (let i = 0; i < rawData.length; i++) {
    outputArray[i] = rawData.charCodeAt(i)
  }

  return outputArray
}
