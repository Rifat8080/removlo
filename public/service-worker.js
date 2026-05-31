self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {}
  const title = data.title || "Removlo update"

  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || "You have a new activity update.",
      icon: "/icon.svg",
      badge: "/icon.svg",
      data: {
        url: data.url || "/dashboard",
        notification_id: data.notification_id
      }
    })
  )
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = event.notification.data?.url || "/dashboard"

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ("focus" in client) {
          client.navigate(url)
          return client.focus()
        }
      }

      return clients.openWindow(url)
    })
  )
})
