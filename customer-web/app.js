const sampleBusinesses = [
  {
    uid: "demo-business",
    role: "hotel",
    businessName: "Demo Business",
    businessCategory: "Preview Only",
    address: "Connect Firebase to load your real businesses",
    phone: "",
    serviceDescription:
      "This preview disappears once Firebase web configuration is added and a customer logs in.",
    bannerImageUrl: "",
    galleryImageUrls: [],
    menuItems: [
      {
        id: "demo-item",
        name: "Preview Item",
        description: "A placeholder menu item while the real backend is not connected.",
        price: 0,
      },
    ],
  },
];

const state = {
  businesses: [],
  filteredBusinesses: [],
  cart: readCart(),
  selectedBusinessId: null,
  currentUser: null,
  currentProfile: null,
  orders: [],
  installEvent: null,
  firebaseReady: false,
  demoMode: false,
  authReady: false,
  expandedBusinesses: new Set(),
};

const els = {
  statusBanner: document.querySelector("#statusBanner"),
  installButton: document.querySelector("#installButton"),
  logoutButton: document.querySelector("#logoutButton"),
  loginTab: document.querySelector("#loginTab"),
  signupTab: document.querySelector("#signupTab"),
  loginForm: document.querySelector("#loginForm"),
  signupForm: document.querySelector("#signupForm"),
  authMessage: document.querySelector("#authMessage"),
  searchInput: document.querySelector("#searchInput"),
  categoryFilter: document.querySelector("#categoryFilter"),
  businessGrid: document.querySelector("#businessGrid"),
  ordersList: document.querySelector("#ordersList"),
  customerName: document.querySelector("#customerName"),
  customerRole: document.querySelector("#customerRole"),
  profileSummary: document.querySelector("#profileSummary"),
  cartBusinessName: document.querySelector("#cartBusinessName"),
  cartItems: document.querySelector("#cartItems"),
  cartCount: document.querySelector("#cartCount"),
  cartTotal: document.querySelector("#cartTotal"),
  placeOrderButton: document.querySelector("#placeOrderButton"),
  cartMessage: document.querySelector("#cartMessage"),
};

const authRefs = {
  app: null,
  auth: null,
  db: null,
  api: null,
};

bootstrap();

async function bootstrap() {
  bindEvents();
  registerServiceWorker();
  await initializeFirebase();
  renderAuthState();
  renderFilters();
  applyFilters();
  renderOrders();
  renderCart();
}

function bindEvents() {
  els.installButton.addEventListener("click", installApp);
  els.logoutButton.addEventListener("click", logout);
  els.loginTab.addEventListener("click", () => switchAuthTab("login"));
  els.signupTab.addEventListener("click", () => switchAuthTab("signup"));
  els.loginForm.addEventListener("submit", onLogin);
  els.signupForm.addEventListener("submit", onSignup);
  els.searchInput.addEventListener("input", applyFilters);
  els.categoryFilter.addEventListener("change", applyFilters);
  els.placeOrderButton.addEventListener("click", placeOrder);

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    state.installEvent = event;
    els.installButton.hidden = false;
  });
}

async function initializeFirebase() {
  const config = window.ZAHLIVERY_FIREBASE_CONFIG;
  if (!config || !config.apiKey || !config.projectId || !config.appId) {
    state.demoMode = true;
    state.authReady = true;
    state.businesses = sampleBusinesses;
    updateStatus(
      "Firebase web config is not set yet. Showing a preview only. Sign up and live orders will start working after you add the real Firebase web config."
    );
    return;
  }

  try {
    const [firebaseAppModule, authModule, firestoreModule] = await Promise.all([
      import("https://www.gstatic.com/firebasejs/11.6.1/firebase-app.js"),
      import("https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js"),
      import("https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js"),
    ]);

    authRefs.app = firebaseAppModule.initializeApp(config);
    authRefs.auth = authModule.getAuth(authRefs.app);
    authRefs.db = firestoreModule.getFirestore(authRefs.app);
    authRefs.api = {
      ...authModule,
      ...firestoreModule,
    };

    state.firebaseReady = true;

    authModule.onAuthStateChanged(authRefs.auth, async (user) => {
      state.currentUser = user ?? null;
      state.currentProfile = null;
      state.orders = [];
      clearMessages();

      if (user) {
        await Promise.all([loadCustomerProfile(user.uid), loadBusinesses(), loadOrders()]);
        updateStatus("Signed in. Browse businesses and place Zahlivery orders.");
      } else {
        state.businesses = [];
        state.filteredBusinesses = [];
        renderFilters();
        applyFilters();
        renderOrders();
        renderCart();
        updateStatus(
          "Create a customer account or login to browse live businesses and place orders."
        );
      }

      state.authReady = true;
      renderAuthState();
    });
  } catch (error) {
    console.error(error);
    state.demoMode = true;
    state.authReady = true;
    state.businesses = sampleBusinesses;
    updateStatus(
      "Firebase failed to initialize in the browser, so the app switched to preview mode."
    );
  }
}

function switchAuthTab(mode) {
  const login = mode === "login";
  els.loginTab.classList.toggle("auth-tab--active", login);
  els.signupTab.classList.toggle("auth-tab--active", !login);
  els.loginForm.hidden = !login;
  els.signupForm.hidden = login;
  setAuthMessage("");
}

async function onLogin(event) {
  event.preventDefault();
  if (!state.firebaseReady) {
    setAuthMessage(
      "Login is disabled until Firebase web config is added to this web app."
    );
    return;
  }

  const email = document.querySelector("#loginEmail").value.trim();
  const password = document.querySelector("#loginPassword").value;

  try {
    setAuthMessage("Signing in...");
    await authRefs.api.signInWithEmailAndPassword(authRefs.auth, email, password);
    els.loginForm.reset();
    setAuthMessage("");
  } catch (error) {
    setAuthMessage(friendlyAuthError(error));
  }
}

async function onSignup(event) {
  event.preventDefault();
  if (!state.firebaseReady) {
    setAuthMessage(
      "Account creation is disabled until Firebase web config is added to this web app."
    );
    return;
  }

  const name = document.querySelector("#signupName").value.trim();
  const phone = document.querySelector("#signupPhone").value.trim();
  const email = document.querySelector("#signupEmail").value.trim();
  const address = document.querySelector("#signupAddress").value.trim();
  const password = document.querySelector("#signupPassword").value;
  const confirmPassword = document.querySelector("#signupConfirmPassword").value;

  if (password !== confirmPassword) {
    setAuthMessage("Passwords do not match.");
    return;
  }

  try {
    setAuthMessage("Creating account...");
    const credential = await authRefs.api.createUserWithEmailAndPassword(
      authRefs.auth,
      email,
      password
    );

    const userDoc = {
      uid: credential.user.uid,
      role: "customer",
      name,
      email,
      phone,
      address,
      businessName: null,
      businessCategory: null,
      serviceDescription: null,
      bannerImageUrl: null,
      galleryImageUrls: [],
      vehicleType: null,
      plateNumber: null,
      createdAt: authRefs.api.serverTimestamp(),
      updatedAt: authRefs.api.serverTimestamp(),
    };

    await authRefs.api.setDoc(
      authRefs.api.doc(authRefs.db, "users", credential.user.uid),
      userDoc
    );

    els.signupForm.reset();
    setAuthMessage("");
    switchAuthTab("login");
  } catch (error) {
    setAuthMessage(friendlyAuthError(error));
  }
}

async function logout() {
  if (!state.firebaseReady) return;
  await authRefs.api.signOut(authRefs.auth);
}

async function loadCustomerProfile(uid) {
  try {
    const snapshot = await authRefs.api.getDoc(authRefs.api.doc(authRefs.db, "users", uid));
    state.currentProfile = snapshot.exists() ? normalizeProfile(snapshot.data()) : null;
  } catch (error) {
    console.error("Failed to load profile", error);
  }
  renderAuthState();
}

async function loadBusinesses() {
  if (!state.currentUser) {
    state.businesses = [];
    renderFilters();
    applyFilters();
    return;
  }

  try {
    const usersRef = authRefs.api.collection(authRefs.db, "users");
    const shopQuery = authRefs.api.query(
      usersRef,
      authRefs.api.where("role", "==", "hotel")
    );
    const shopSnapshot = await authRefs.api.getDocs(shopQuery);

    const businesses = await Promise.all(
      shopSnapshot.docs.map(async (docSnapshot) => {
        const raw = docSnapshot.data();
        const menuRef = authRefs.api.collection(
          authRefs.db,
          "users",
          docSnapshot.id,
          "menuItems"
        );
        const menuQuery = authRefs.api.query(
          menuRef,
          authRefs.api.where("available", "==", true)
        );
        const menuSnapshot = await authRefs.api.getDocs(menuQuery);
        const menuItems = menuSnapshot.docs
          .map((menuDoc) => normalizeMenuItem(menuDoc.id, menuDoc.data()))
          .filter(Boolean)
          .sort((a, b) => a.name.localeCompare(b.name));

        return normalizeBusiness({
          uid: docSnapshot.id,
          ...raw,
          menuItems,
        });
      })
    );

    state.businesses = businesses
      .filter(Boolean)
      .sort((a, b) => a.businessName.localeCompare(b.businessName));
  } catch (error) {
    console.error("Failed to load businesses", error);
    state.businesses = [];
    updateStatus(
      "Signed in, but business data could not be loaded. If this is a Firestore rules or missing data issue, we can ignore it for now and keep improving the web app."
    );
  }

  renderFilters();
  applyFilters();
}

async function loadOrders() {
  if (!state.currentUser) {
    state.orders = [];
    renderOrders();
    return;
  }

  try {
    const ordersRef = authRefs.api.collection(authRefs.db, "orders");
    const orderQuery = authRefs.api.query(
      ordersRef,
      authRefs.api.where("customerId", "==", state.currentUser.uid)
    );
    const snapshot = await authRefs.api.getDocs(orderQuery);
    state.orders = snapshot.docs
      .map((docSnapshot) => normalizeOrder(docSnapshot.id, docSnapshot.data()))
      .filter(Boolean)
      .sort((a, b) => b.createdAtMillis - a.createdAtMillis);
  } catch (error) {
    console.error("Failed to load orders", error);
    state.orders = [];
  }

  renderOrders();
}

function renderAuthState() {
  const isSignedIn = Boolean(state.currentUser);
  els.logoutButton.hidden = !isSignedIn;

  if (!state.authReady) {
    els.customerName.textContent = "Loading...";
    els.profileSummary.innerHTML = "<p>Checking your session...</p>";
    return;
  }

  if (state.currentProfile) {
    els.customerName.textContent = state.currentProfile.name || "Customer";
    els.customerRole.textContent = "Customer";
    els.profileSummary.innerHTML = `
      <p><strong>Email:</strong> ${escapeHtml(state.currentProfile.email || "-")}</p>
      <p><strong>Phone:</strong> ${escapeHtml(state.currentProfile.phone || "-")}</p>
      <p><strong>Address:</strong> ${escapeHtml(state.currentProfile.address || "-")}</p>
    `;
  } else if (state.demoMode) {
    els.customerName.textContent = "Preview Mode";
    els.customerRole.textContent = "Customer";
    els.profileSummary.innerHTML =
      "<p>Connect Firebase web config to enable real customer accounts and backend data.</p>";
  } else {
    els.customerName.textContent = "Guest";
    els.customerRole.textContent = "Customer";
    els.profileSummary.innerHTML =
      "<p>Create a customer account or login to browse live businesses and place orders.</p>";
  }
}

function renderFilters() {
  const categories = [
    "all",
    ...new Set(state.businesses.map((business) => business.businessCategory)),
  ];

  els.categoryFilter.innerHTML = "";
  categories.forEach((category) => {
    const option = document.createElement("option");
    option.value = category;
    option.textContent = category === "all" ? "All categories" : category;
    els.categoryFilter.append(option);
  });
}

function applyFilters() {
  const searchTerm = cleanString(els.searchInput.value).toLowerCase();
  const category = els.categoryFilter.value || "all";

  state.filteredBusinesses = state.businesses.filter((business) => {
    const matchesCategory =
      category === "all" || business.businessCategory === category;
    const haystack = [
      business.businessName,
      business.businessCategory,
      business.address,
      business.serviceDescription,
    ]
      .join(" ")
      .toLowerCase();
    return matchesCategory && haystack.includes(searchTerm);
  });

  renderBusinesses();
}

function renderBusinesses() {
  els.businessGrid.innerHTML = "";

  if (state.filteredBusinesses.length === 0) {
    els.businessGrid.innerHTML =
      "<p class='empty-state'>No businesses available yet for this view.</p>";
    return;
  }

  const businessTemplate = document.querySelector("#businessCardTemplate");
  const menuTemplate = document.querySelector("#menuItemTemplate");

  state.filteredBusinesses.forEach((business) => {
    const fragment = businessTemplate.content.cloneNode(true);
    const card = fragment.querySelector(".business-card");
    const media = fragment.querySelector(".business-card__media");
    const category = fragment.querySelector(".business-card__category");
    const menuCount = fragment.querySelector(".business-card__menu-count");
    const name = fragment.querySelector(".business-card__name");
    const description = fragment.querySelector(".business-card__description");
    const meta = fragment.querySelector(".business-card__meta");
    const viewButton = fragment.querySelector(".business-card__view");
    const menuPreview = fragment.querySelector(".menu-preview");

    const coverImage = business.bannerImageUrl || business.galleryImageUrls[0] || "";
    if (coverImage) {
      const image = document.createElement("img");
      image.src = coverImage;
      image.alt = business.businessName;
      media.append(image);
    } else {
      media.innerHTML =
        "<div style='height:100%;display:grid;place-items:center;padding:24px;text-align:center;font-weight:700;color:#315f00;line-height:1.4;'>" +
        escapeHtml(business.businessName) +
        "<br />" +
        escapeHtml(business.businessCategory) +
        "</div>";
    }

    category.textContent = business.businessCategory;
    menuCount.textContent = `${business.menuItems.length} item${
      business.menuItems.length === 1 ? "" : "s"
    }`;
    name.textContent = business.businessName;
    description.textContent = business.serviceDescription;
    meta.innerHTML = `
      <span>${escapeHtml(business.address || "-")}</span>
      <span>${escapeHtml(business.phone || "Phone hidden")}</span>
    `;

    const isExpanded = state.expandedBusinesses.has(business.uid);
    const visibleItems = isExpanded ? business.menuItems : business.menuItems.slice(0, 3);

    visibleItems.forEach((item) => {
      const menuFragment = menuTemplate.content.cloneNode(true);
      menuFragment.querySelector(".menu-item__name").textContent = item.name;
      menuFragment.querySelector(".menu-item__price").textContent = formatCurrency(item.price);
      menuFragment.querySelector(".menu-item__description").textContent = item.description;
      menuFragment.querySelector(".menu-item__add").addEventListener("click", () => {
        addToCart(business.uid, item.id);
      });
      menuPreview.append(menuFragment);
    });

    viewButton.textContent = isExpanded ? "Hide Menu" : "View Menu";
    viewButton.addEventListener("click", () => {
      if (state.expandedBusinesses.has(business.uid)) {
        state.expandedBusinesses.delete(business.uid);
      } else {
        state.expandedBusinesses.add(business.uid);
      }
      state.selectedBusinessId = business.uid;
      renderBusinesses();
      renderCart();
      card.scrollIntoView({ behavior: "smooth", block: "center" });
    });

    els.businessGrid.append(fragment);
  });
}

function addToCart(businessId, itemId) {
  const business = state.businesses.find((entry) => entry.uid === businessId);
  const item = business?.menuItems.find((entry) => entry.id === itemId);
  if (!business || !item) return;

  state.selectedBusinessId = businessId;
  const existing = state.cart.find(
    (entry) => entry.businessId === businessId && entry.itemId === itemId
  );

  if (existing) {
    existing.quantity += 1;
  } else {
    state.cart.push({
      businessId,
      businessName: business.businessName,
      itemId,
      name: item.name,
      price: item.price,
      quantity: 1,
    });
  }

  persistCart();
  renderCart();
}

function renderCart() {
  const cartItems = getSelectedCartItems();
  const business = getSelectedBusiness();

  els.cartBusinessName.textContent = business
    ? business.businessName
    : "Select a business";

  if (cartItems.length === 0) {
    els.cartItems.innerHTML =
      "<p class='empty-state'>Add menu items from a business to prepare an order.</p>";
    els.cartCount.textContent = "0 items";
    els.cartTotal.textContent = formatCurrency(0);
    return;
  }

  els.cartItems.innerHTML = "";
  const totalQuantity = cartItems.reduce((sum, item) => sum + item.quantity, 0);
  const total = cartItems.reduce(
    (sum, item) => sum + item.quantity * item.price,
    0
  );

  cartItems.forEach((item) => {
    const line = document.createElement("article");
    line.className = "cart-line";
    line.innerHTML = `
      <div class="cart-line__header">
        <strong>${escapeHtml(item.name)}</strong>
        <span>${formatCurrency(item.price * item.quantity)}</span>
      </div>
      <div class="cart-line__footer">
        <span>${item.quantity} x ${formatCurrency(item.price)}</span>
        <div class="cart-line__actions">
          <button class="icon-button" type="button" aria-label="Remove one">-</button>
          <button class="icon-button" type="button" aria-label="Add one">+</button>
        </div>
      </div>
    `;

    const [removeButton, addButton] = line.querySelectorAll(".icon-button");
    removeButton.addEventListener("click", () => updateQuantity(item, -1));
    addButton.addEventListener("click", () => updateQuantity(item, 1));
    els.cartItems.append(line);
  });

  els.cartCount.textContent = `${totalQuantity} item${totalQuantity === 1 ? "" : "s"}`;
  els.cartTotal.textContent = formatCurrency(total);
}

function updateQuantity(target, delta) {
  const entry = state.cart.find(
    (item) =>
      item.businessId === target.businessId && item.itemId === target.itemId
  );
  if (!entry) return;

  entry.quantity += delta;
  if (entry.quantity <= 0) {
    state.cart = state.cart.filter(
      (item) =>
        !(item.businessId === target.businessId && item.itemId === target.itemId)
    );
  }

  persistCart();
  renderCart();
}

async function placeOrder() {
  clearCartMessage();

  if (!state.currentUser || !state.currentProfile) {
    setCartMessage("Login first so your order can be saved in Zahlivery.");
    return;
  }

  if (!state.firebaseReady) {
    setCartMessage("Ordering is disabled until Firebase web config is connected.");
    return;
  }

  const business = getSelectedBusiness();
  const items = getSelectedCartItems();
  if (!business || items.length === 0) {
    setCartMessage("Add items from one business before placing an order.");
    return;
  }

  const total = items.reduce((sum, item) => sum + item.quantity * item.price, 0);
  const payloadItems = items.map((item) => ({
    menuItemId: item.itemId,
    name: item.name,
    price: item.price,
    qty: item.quantity,
    lineTotal: item.price * item.quantity,
    imageUrl: "",
    imageUrls: [],
  }));

  try {
    setCartMessage("Placing order...");
    await authRefs.api.addDoc(authRefs.api.collection(authRefs.db, "orders"), {
      customerId: state.currentUser.uid,
      customerName: state.currentProfile.name,
      customerPhone: state.currentProfile.phone,
      customerAddress: state.currentProfile.address || "",
      hotelId: business.uid,
      hotelName: business.businessName,
      status: "pending",
      source: "menu",
      paymentStatus: "awaiting_payment",
      items: payloadItems,
      totalAmount: total,
      createdAt: authRefs.api.serverTimestamp(),
      updatedAt: authRefs.api.serverTimestamp(),
    });

    state.cart = state.cart.filter((item) => item.businessId !== business.uid);
    persistCart();
    renderCart();
    await loadOrders();
    setCartMessage("Order placed successfully and saved in Zahlivery.");
  } catch (error) {
    console.error("Failed to place order", error);
    setCartMessage(
      "The order could not be created from the browser. If this comes from your Firebase setup, we can ignore it for now and keep the flow in place."
    );
  }
}

function renderOrders() {
  if (!state.currentUser) {
    els.ordersList.innerHTML =
      "<p class='empty-state'>Login to view your Zahlivery orders.</p>";
    return;
  }

  if (state.orders.length === 0) {
    els.ordersList.innerHTML =
      "<p class='empty-state'>No orders yet. Create one from the businesses section.</p>";
    return;
  }

  els.ordersList.innerHTML = "";
  state.orders.forEach((order) => {
    const card = document.createElement("article");
    card.className = "order-card";
    card.innerHTML = `
      <div class="order-card__topline">
        <h4>${escapeHtml(order.hotelName)}</h4>
        <span class="order-card__status">${escapeHtml(order.status)}</span>
      </div>
      <p>Order ID: ${escapeHtml(order.id)}</p>
      <p>Total: ${formatCurrency(order.totalAmount)}</p>
      <p>Payment: ${escapeHtml(order.paymentStatus)}</p>
      <p>${escapeHtml(order.createdAtLabel)}</p>
    `;
    els.ordersList.append(card);
  });
}

function normalizeBusiness(raw) {
  if (!raw) return null;
  const name = cleanString(raw.businessName || raw.name || "Business");
  return {
    uid: cleanString(raw.uid),
    role: cleanString(raw.role || "hotel"),
    businessName: name,
    businessCategory: cleanString(raw.businessCategory || "Business"),
    address: cleanString(raw.address || "Address not shared yet"),
    phone: cleanString(raw.phone || ""),
    serviceDescription: cleanString(
      raw.serviceDescription || "No description added yet."
    ),
    bannerImageUrl: cleanString(raw.bannerImageUrl || ""),
    galleryImageUrls: Array.isArray(raw.galleryImageUrls)
      ? raw.galleryImageUrls.map(cleanString).filter(Boolean)
      : [],
    menuItems: Array.isArray(raw.menuItems) ? raw.menuItems.filter(Boolean) : [],
  };
}

function normalizeMenuItem(id, raw) {
  if (!raw) return null;
  const price = Number(raw.price ?? 0);
  return {
    id: cleanString(id),
    name: cleanString(raw.name || "Item"),
    description: cleanString(raw.description || "No description provided."),
    price: Number.isFinite(price) ? price : 0,
  };
}

function normalizeProfile(raw) {
  if (!raw) return null;
  return {
    uid: cleanString(raw.uid),
    role: cleanString(raw.role || "customer"),
    name: cleanString(raw.name || ""),
    email: cleanString(raw.email || ""),
    phone: cleanString(raw.phone || ""),
    address: cleanString(raw.address || ""),
  };
}

function normalizeOrder(id, raw) {
  if (!raw) return null;
  const createdAtDate = raw.createdAt?.toDate ? raw.createdAt.toDate() : null;
  return {
    id: cleanString(id),
    hotelName: cleanString(raw.hotelName || "Business"),
    status: cleanString(raw.status || "pending"),
    paymentStatus: cleanString(raw.paymentStatus || "awaiting_payment"),
    totalAmount: Number(raw.totalAmount ?? 0),
    createdAtMillis: createdAtDate ? createdAtDate.getTime() : 0,
    createdAtLabel: createdAtDate
      ? `Created ${createdAtDate.toLocaleString()}`
      : "Created just now",
  };
}

function getSelectedBusiness() {
  return state.businesses.find((entry) => entry.uid === state.selectedBusinessId);
}

function getSelectedCartItems() {
  return state.selectedBusinessId
    ? state.cart.filter((item) => item.businessId === state.selectedBusinessId)
    : [];
}

function setAuthMessage(message) {
  els.authMessage.textContent = message;
}

function setCartMessage(message) {
  els.cartMessage.textContent = message;
}

function clearMessages() {
  setAuthMessage("");
  clearCartMessage();
}

function clearCartMessage() {
  setCartMessage("");
}

function updateStatus(message) {
  els.statusBanner.textContent = message;
}

function installApp() {
  if (state.installEvent) {
    state.installEvent.prompt();
    return;
  }
  window.alert(
    "On iPhone Safari, tap Share then 'Add to Home Screen'. On Chrome, use 'Install app'."
  );
}

function friendlyAuthError(error) {
  const code = error?.code || "";
  switch (code) {
    case "auth/email-already-in-use":
      return "This email is already used by another account.";
    case "auth/weak-password":
      return "Password is too weak. Use at least 6 characters.";
    case "auth/invalid-email":
      return "Email format is invalid.";
    case "auth/invalid-credential":
    case "auth/user-not-found":
    case "auth/wrong-password":
      return "Invalid email or password.";
    case "auth/network-request-failed":
      return "Network error. Check your connection and try again.";
    default:
      return error?.message || "Authentication error occurred.";
  }
}

function registerServiceWorker() {
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("./sw.js").catch((error) => {
      console.error("Service worker registration failed", error);
    });
  }
}

function persistCart() {
  localStorage.setItem("zahlivery-web-cart", JSON.stringify(state.cart));
}

function readCart() {
  try {
    const raw = localStorage.getItem("zahlivery-web-cart");
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function cleanString(value) {
  return String(value ?? "").trim();
}

function formatCurrency(amount) {
  return new Intl.NumberFormat("en-KE", {
    style: "currency",
    currency: "KES",
    maximumFractionDigits: 0,
  }).format(amount);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
