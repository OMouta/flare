const login = document.querySelector("#login");
const chat = document.querySelector("#chat");
const loginForm = document.querySelector("#login-form");
const messageForm = document.querySelector("#message-form");
const usernameInput = document.querySelector("#username");
const messageInput = document.querySelector("#message");
const messagesEl = document.querySelector("#messages");
const activeUser = document.querySelector("#active-user");
const logout = document.querySelector("#logout");

let username = localStorage.getItem("flare-chat-username") || "";
let lastRendered = "";

function showChat() {
	login.classList.add("hidden");
	chat.classList.remove("hidden");
	activeUser.textContent = username;
	messageInput.focus();
	loadMessages();
}

function showLogin() {
	chat.classList.add("hidden");
	login.classList.remove("hidden");
	usernameInput.value = username;
	usernameInput.focus();
}

function renderMessages(messages) {
	const fingerprint = JSON.stringify(messages);
	if (fingerprint === lastRendered) {
		return;
	}

	lastRendered = fingerprint;
	messagesEl.replaceChildren();

	for (const message of messages) {
		const row = document.createElement("article");
		row.className = message.username === username ? "message mine" : "message";

		const author = document.createElement("strong");
		author.textContent = message.username;

		const text = document.createElement("p");
		text.textContent = message.text;

		row.append(author, text);
		messagesEl.append(row);
	}

	messagesEl.scrollTop = messagesEl.scrollHeight;
}

async function loadMessages() {
	if (!username) {
		return;
	}

	const response = await fetch("/api/messages");
	if (!response.ok) {
		return;
	}

	const body = await response.json();
	renderMessages(body.messages || []);
}

loginForm.addEventListener("submit", (event) => {
	event.preventDefault();
	username = usernameInput.value.trim();
	if (!username) {
		return;
	}

	localStorage.setItem("flare-chat-username", username);
	showChat();
});

messageForm.addEventListener("submit", async (event) => {
	event.preventDefault();
	const text = messageInput.value.trim();
	if (!text) {
		return;
	}

	messageInput.value = "";

	await fetch("/api/messages", {
		method: "POST",
		headers: {
			"content-type": "application/json",
		},
		body: JSON.stringify({
			username,
			text,
		}),
	});

	await loadMessages();
});

logout.addEventListener("click", () => {
	localStorage.removeItem("flare-chat-username");
	username = "";
	showLogin();
});

if (username) {
	showChat();
} else {
	showLogin();
}

setInterval(loadMessages, 1000);
