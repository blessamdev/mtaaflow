import { useEffect, useMemo, useState, type ReactNode } from "react";

type View = "home" | "store" | "studio" | "tracking";
type Status = "NEW" | "CONFIRMED" | "PAID" | "PREPARING" | "COMPLETED";
type StudioPage = "Overview" | "Orders" | "Products" | "Customers" | "Analytics" | "Store settings";
type Product = {
  id: number;
  name: string;
  price: number;
  category: string;
  description: string;
  stock: number;
  sizes: string[];
  colors: { name: string; hex: string }[];
  images: string[];
};
type CartItem = { productId: number; size: string; color: string; qty: number };
type Customer = { name: string; phone: string; email: string; location: string };
type DemoOrder = {
  ref: string;
  items: CartItem[];
  customer: Customer;
  delivery: "Delivery" | "Store pickup";
  address: string;
  payment: "M-Pesa" | "Pay on delivery";
  total: number;
  created: string;
};

const img = (id: string) => `https://images.unsplash.com/${id}?auto=format&fit=crop&w=800&q=80`;
const products: Product[] = [
  {
    id: 1,
    name: "Nairobi Nights Hoodie",
    price: 4200,
    category: "Hoodies",
    description:
      "A heavyweight brushed-cotton hoodie made for cool Nairobi nights. Relaxed shoulders, roomy pocket and a clean embroidered UT monogram.",
    stock: 8,
    sizes: ["S", "M", "L", "XL"],
    colors: [
      { name: "Forest", hex: "#28463c" },
      { name: "Onyx", hex: "#1e201f" },
      { name: "Clay", hex: "#ad6b48" },
    ],
    images: [img("photo-1580079906050-84bb132e4c4f"), img("photo-1678382998507-8e8f2bee31d6")],
  },
  {
    id: 2,
    name: "CBD Utility Cargo",
    price: 3600,
    category: "Cargo pants",
    description:
      "Everyday utility trousers with a tapered shape, adjustable ankle cords and six practical pockets. Built for movement across the city.",
    stock: 5,
    sizes: ["28", "30", "32", "34", "36"],
    colors: [
      { name: "Olive", hex: "#626b4f" },
      { name: "Black", hex: "#202322" },
    ],
    images: [img("photo-1736097761594-47aaa3b0b2e5"), img("photo-1793443696225-7ec493d220b0")],
  },
  {
    id: 3,
    name: "Matatu Type Tee",
    price: 1850,
    category: "T-shirts",
    description:
      "A premium 240gsm cotton tee inspired by Nairobi's bold matatu typography. Screen printed locally in a relaxed unisex cut.",
    stock: 14,
    sizes: ["XS", "S", "M", "L", "XL"],
    colors: [
      { name: "Black", hex: "#1e201f" },
      { name: "Bone", hex: "#e4ddcd" },
    ],
    images: [img("photo-1614565254221-27fa099f94b4"), img("photo-1763750581767-b367bcd6c117")],
  },
  {
    id: 4,
    name: "City Runner Jacket",
    price: 5800,
    category: "Jackets",
    description:
      "A lightweight statement jacket with water-resistant panels, breathable lining and an adjustable hem for changing city weather.",
    stock: 3,
    sizes: ["S", "M", "L", "XL"],
    colors: [
      { name: "Ember", hex: "#d76632" },
      { name: "Graphite", hex: "#3e4542" },
    ],
    images: [img("photo-1554925051-f668ed70d520"), img("photo-1554924319-e5314b2e37dd")],
  },
  {
    id: 5,
    name: "Mtaa Five-Panel Cap",
    price: 1450,
    category: "Accessories",
    description:
      "A low-profile five-panel cap with an adjustable back strap and understated Mtaa embroidery.",
    stock: 11,
    sizes: ["One size"],
    colors: [
      { name: "Olive", hex: "#626b4f" },
      { name: "Black", hex: "#202322" },
    ],
    images: [img("photo-1628861997489-a432a904e028"), img("photo-1651050129240-a6ecb87ac2c9")],
  },
  {
    id: 6,
    name: "Archive Graphic Tee",
    price: 2100,
    category: "T-shirts",
    description:
      "A soft heavyweight jersey tee with a limited seasonal front graphic and dropped shoulders.",
    stock: 9,
    sizes: ["S", "M", "L", "XL"],
    colors: [
      { name: "White", hex: "#efeee9" },
      { name: "Black", hex: "#202322" },
    ],
    images: [img("photo-1715146912865-cc51c9eb6e1b"), img("photo-1765923769309-6dac56971018")],
  },
];

const money = (n: number) => `KSh ${n.toLocaleString("en-KE")}`;
const statusIndex = (s: Status) =>
  ["NEW", "CONFIRMED", "PAID", "PREPARING", "COMPLETED"].indexOf(s);

function Icon({
  name,
  size = 20,
  className = "",
}: {
  name: string;
  size?: number;
  className?: string;
}) {
  const p: Record<string, ReactNode> = {
    arrow: (
      <>
        <path d="M5 12h14" />
        <path d="m14 7 5 5-5 5" />
      </>
    ),
    back: <path d="m15 18-6-6 6-6" />,
    cart: (
      <>
        <circle cx="9" cy="20" r="1" />
        <circle cx="18" cy="20" r="1" />
        <path d="M3 4h2l2.4 10.3a2 2 0 0 0 2 1.6h7.9a2 2 0 0 0 2-1.6L21 7H6" />
      </>
    ),
    check: <path d="m5 12 4 4L19 6" />,
    close: <path d="m6 6 12 12M18 6 6 18" />,
    copy: (
      <>
        <rect x="8" y="8" width="12" height="12" rx="2" />
        <path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" />
      </>
    ),
    grid: (
      <>
        <rect x="4" y="4" width="6" height="6" rx="1" />
        <rect x="14" y="4" width="6" height="6" rx="1" />
        <rect x="4" y="14" width="6" height="6" rx="1" />
        <rect x="14" y="14" width="6" height="6" rx="1" />
      </>
    ),
    link: (
      <>
        <path d="M10 13a5 5 0 0 0 7 .1l2-2A5 5 0 0 0 12 4l-1 1" />
        <path d="M14 11a5 5 0 0 0-7-.1l-2 2A5 5 0 0 0 12 20l1-1" />
      </>
    ),
    menu: <path d="M4 7h16M4 12h16M4 17h16" />,
    minus: <path d="M5 12h14" />,
    order: (
      <>
        <path d="M6 3h12v18H6z" />
        <path d="M9 8h6M9 12h6M9 16h4" />
      </>
    ),
    plus: <path d="M12 5v14M5 12h14" />,
    search: (
      <>
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-4-4" />
      </>
    ),
    share: (
      <>
        <circle cx="18" cy="5" r="2" />
        <circle cx="6" cy="12" r="2" />
        <circle cx="18" cy="19" r="2" />
        <path d="m8 11 8-5M8 13l8 5" />
      </>
    ),
    spark: <path d="m12 3 1.4 5.6L19 10l-5.6 1.4L12 17l-1.4-5.6L5 10l5.6-1.4L12 3Z" />,
    trash: (
      <>
        <path d="M4 7h16M9 7V4h6v3M7 7l1 14h8l1-14M10 11v6M14 11v6" />
      </>
    ),
    user: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4 21a8 8 0 0 1 16 0" />
      </>
    ),
    chart: (
      <>
        <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />
      </>
    ),
    settings: (
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M12 2v3M12 19v3M4.9 4.9 7 7M17 17l2.1 2.1M2 12h3M19 12h3M4.9 19.1 7 17M17 7l2.1-2.1" />
      </>
    ),
    whatsapp: (
      <>
        <path d="M20 11.7a8 8 0 0 1-11.7 7.1L4 20l1.2-4.1A8 8 0 1 1 20 11.7Z" />
        <path d="M9 8.5c1 3 2.5 4.5 5.5 5.5" />
      </>
    ),
  };
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {p[name]}
    </svg>
  );
}

function Logo({ light = false, onClick }: { light?: boolean; onClick?: () => void }) {
  return (
    <button onClick={onClick} className="flex items-center gap-2.5" aria-label="MtaaFlow home">
      <span
        className={`grid h-9 w-9 place-items-center rounded-xl ${light ? "bg-white text-[#172b25]" : "bg-[#172b25] text-white"}`}
      >
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M4 14V7.4L10 4l6 3.4V14l-6 3-6-3Z" stroke="currentColor" strokeWidth="1.7" />
          <path d="M7 13V9l3 2 3-2v4" stroke="currentColor" strokeWidth="1.7" />
        </svg>
      </span>
      <span
        className={`text-[19px] font-extrabold tracking-[-.04em] ${light ? "text-white" : "text-[#172b25]"}`}
      >
        MtaaFlow
      </span>
    </button>
  );
}

function StatusPill({ status }: { status: Status }) {
  const style =
    status === "NEW"
      ? "bg-[#fff0e8] text-[#bd562b]"
      : status === "COMPLETED"
        ? "bg-[#e4f2d9] text-[#346347]"
        : "bg-[#edf1e9] text-[#52645b]";
  return (
    <span className={`rounded-full px-2.5 py-1 text-[9px] font-extrabold ${style}`}>{status}</span>
  );
}

function HeroPreview({ go }: { go: (v: View, product?: number) => void }) {
  const [mode, setMode] = useState<"customer" | "seller">("customer");
  return (
    <div className="relative mx-auto w-full max-w-[540px]">
      <div className="mb-4 flex justify-center">
        <div className="flex rounded-full border border-black/10 bg-white p-1 shadow-sm">
          {(["customer", "seller"] as const).map((m) => (
            <button
              key={m}
              onClick={() => setMode(m)}
              className={`rounded-full px-5 py-2 text-xs font-extrabold capitalize transition-all ${mode === m ? "bg-[#172b25] text-white shadow" : "text-[#64736c]"}`}
            >
              {m} view
            </button>
          ))}
        </div>
      </div>
      <div className="relative h-[550px] overflow-hidden rounded-[32px] border-[7px] border-[#172b25] bg-white shadow-[0_35px_80px_rgba(23,43,37,.22)]">
        <div
          className={`absolute inset-0 transition-all duration-500 ${mode === "customer" ? "translate-x-0 opacity-100" : "-translate-x-8 opacity-0 pointer-events-none"}`}
        >
          <div className="flex items-center justify-between p-4">
            <b className="text-sm tracking-[.12em]">URBAN THREADS KE</b>
            <Icon name="cart" size={18} />
          </div>
          <button
            onClick={() => go("store", 1)}
            className="relative block h-[335px] w-full overflow-hidden text-left"
          >
            <img
              src={products[0].images[0]}
              className="h-full w-full object-cover object-top"
              alt="Nairobi Nights Hoodie"
            />
            <span className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />
            <span className="absolute bottom-5 left-5 text-white">
              <small className="font-bold uppercase tracking-[.18em]">New drop</small>
              <strong className="mt-1 block text-2xl">Nairobi Nights</strong>
              <span className="mt-2 block text-xs font-bold">Shop now →</span>
            </span>
          </button>
          <div className="grid grid-cols-2 gap-3 p-4">
            {products.slice(1, 3).map((p) => (
              <button key={p.id} onClick={() => go("store", p.id)} className="text-left">
                <img
                  src={p.images[0]}
                  className="h-24 w-full rounded-xl object-cover object-top"
                  alt=""
                />
                <b className="mt-2 block truncate text-[11px]">{p.name}</b>
                <span className="text-[10px] text-[#6c7972]">{money(p.price)}</span>
              </button>
            ))}
          </div>
        </div>
        <div
          className={`absolute inset-0 bg-[#f4f5f1] p-5 transition-all duration-500 ${mode === "seller" ? "translate-x-0 opacity-100" : "translate-x-8 opacity-0 pointer-events-none"}`}
        >
          <div className="flex items-center justify-between">
            <div>
              <small className="text-[#748079]">Seller Studio</small>
              <h3 className="font-black">Good morning, Urban Threads.</h3>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#dce9cf] text-[10px] font-black">
              UT
            </span>
          </div>
          <div className="mt-5 grid grid-cols-2 gap-3">
            <div className="rounded-xl bg-white p-3">
              <small>Demo orders</small>
              <b className="mt-2 block text-2xl">18</b>
              <span className="text-[9px] text-[#3d7558]">+3 this week</span>
            </div>
            <div className="rounded-xl bg-[#172b25] p-3 text-white">
              <small className="text-white/50">Demo sales</small>
              <b className="mt-2 block text-2xl">42.8K</b>
              <span className="text-[9px] text-white/50">KSh this month</span>
            </div>
          </div>
          <div className="mt-4 rounded-2xl bg-white p-4">
            <div className="flex items-center justify-between">
              <b className="text-xs">Incoming orders</b>
              <span className="text-[9px] text-[#e06a38]">3 new</span>
            </div>
            {["Wanjiku Kamau", "Brian Otieno", "Amina Noor"].map((n, i) => (
              <div key={n} className="mt-4 flex items-center gap-3 border-t border-black/5 pt-3">
                <span className="grid h-8 w-8 place-items-center rounded-full bg-[#edf1e9] text-[9px] font-black">
                  {n
                    .split(" ")
                    .map((x) => x[0])
                    .join("")}
                </span>
                <div className="min-w-0 flex-1">
                  <b className="block truncate text-[10px]">{n}</b>
                  <small className="text-[9px] text-[#748079]">{products[i].name}</small>
                </div>
                <b className="text-[10px]">{money(products[i].price)}</b>
              </div>
            ))}
          </div>
          <button
            onClick={() => go("studio")}
            className="mt-4 w-full rounded-full bg-[#172b25] py-3 text-xs font-extrabold text-white"
          >
            Open Seller Studio
          </button>
        </div>
      </div>
      <div className="absolute -left-5 top-32 z-10 rounded-2xl bg-white p-3 shadow-xl">
        <div className="flex items-center gap-2">
          <span className="grid h-9 w-9 place-items-center rounded-full bg-[#e5f1d9]">
            <Icon name="order" size={16} />
          </span>
          <div>
            <small className="block text-[9px] text-[#748079]">New demo order</small>
            <b className="text-xs">KSh 4,200</b>
          </div>
        </div>
      </div>
    </div>
  );
}

function SocialPost({ shop }: { shop: () => void }) {
  return (
    <div className="overflow-hidden rounded-[24px] bg-white shadow-xl shadow-black/10">
      <div className="flex items-center gap-3 p-3">
        <span className="grid h-9 w-9 place-items-center rounded-full bg-[#172b25] text-[9px] font-black text-white">
          UT
        </span>
        <div>
          <b className="block text-xs">urbanthreads.ke</b>
          <small className="text-[9px] text-[#748079]">Nairobi, Kenya • Sponsored demo</small>
        </div>
      </div>
      <div className="relative aspect-square">
        <img
          src={products[0].images[0]}
          className="h-full w-full object-cover object-top"
          alt="Nairobi Nights Hoodie social post"
        />
        <span className="absolute bottom-3 left-3 rounded-full bg-white/95 px-3 py-1.5 text-[10px] font-black">
          {money(products[0].price)}
        </span>
      </div>
      <div className="p-4">
        <p className="text-xs leading-5">
          <b>urbanthreads.ke</b> Nairobi nights call for something warmer. Forest drop now live.
        </p>
        <button
          onClick={shop}
          className="mt-3 flex w-full items-center justify-between rounded-xl bg-[#172b25] px-4 py-3 text-xs font-extrabold text-white"
        >
          Shop this hoodie <Icon name="arrow" size={15} />
        </button>
      </div>
    </div>
  );
}

function Landing({
  go,
  builder,
}: {
  go: (v: View, product?: number) => void;
  builder: () => void;
}) {
  const [stage, setStage] = useState(0);
  return (
    <div className="bg-[#fbfaf6] text-[#172b25]">
      <header className="fixed inset-x-0 top-0 z-40 border-b border-black/5 bg-[#fbfaf6]/90 backdrop-blur-xl">
        <div className="mx-auto flex h-[74px] max-w-[1180px] items-center justify-between px-5 sm:px-8">
          <Logo onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })} />
          <nav className="hidden gap-7 text-xs font-bold md:flex">
            <a href="#journey">Live journey</a>
            <a href="#features">Features</a>
            <button onClick={() => go("tracking")}>Track order</button>
          </nav>
          <div className="flex gap-2">
            <button
              onClick={() => go("studio")}
              className="hidden rounded-full px-4 py-2.5 text-xs font-bold sm:block"
            >
              Seller Studio
            </button>
            <button
              onClick={builder}
              className="rounded-full bg-[#172b25] px-5 py-3 text-xs font-extrabold text-white"
            >
              Create your store
            </button>
          </div>
        </div>
      </header>
      <main>
        <section className="overflow-hidden px-5 pb-24 pt-32 sm:px-8 lg:pt-40">
          <div className="mx-auto grid max-w-[1180px] items-center gap-14 lg:grid-cols-[1.03fr_.97fr]">
            <div>
              <span className="inline-flex items-center gap-2 rounded-full border border-[#d6ddd7] bg-white px-3.5 py-2 text-[10px] font-extrabold uppercase tracking-[.12em]">
                <i className="h-2 w-2 rounded-full bg-[#e8743c]" /> Social commerce, organised
              </span>
              <h1 className="mt-7 text-[50px] font-extrabold leading-[.98] tracking-[-.062em] sm:text-[69px] lg:text-[75px]">
                Your business deserves more than a{" "}
                <span className="text-[#de6633]">social page.</span>
              </h1>
              <p className="mt-7 max-w-[570px] text-lg leading-8 text-[#596861]">
                Create a beautiful online store, share one link and turn social media attention into
                organised customer orders.
              </p>
              <div className="mt-9 flex flex-col gap-3 sm:flex-row">
                <button
                  onClick={builder}
                  className="flex items-center justify-center gap-3 rounded-full bg-[#172b25] px-7 py-4 text-sm font-extrabold text-white shadow-xl transition hover:-translate-y-0.5"
                >
                  Create your free store <Icon name="arrow" size={17} />
                </button>
                <button
                  onClick={() => go("store")}
                  className="rounded-full border border-black/10 bg-white px-7 py-4 text-sm font-extrabold"
                >
                  Explore live demo
                </button>
              </div>
              <p className="mt-6 text-[11px] font-semibold text-[#7b8882]">
                No coding • No account needed for this demo • Built mobile-first
              </p>
            </div>
            <HeroPreview go={go} />
          </div>
        </section>
        <section className="border-y border-black/5 bg-white py-5">
          <div className="mx-auto flex max-w-[1180px] flex-col items-center justify-between gap-4 px-5 md:flex-row">
            <b className="text-xs">Sell where your customers already discover you</b>
            <div className="flex gap-7 text-sm font-black text-[#7b8882]">
              <span>TikTok</span>
              <span>Instagram</span>
              <span>WhatsApp</span>
              <span>Facebook</span>
            </div>
          </div>
        </section>

        <section id="journey" className="px-5 py-24 sm:px-8 lg:py-32">
          <div className="mx-auto max-w-[1180px]">
            <div className="text-center">
              <p className="eyebrow">Try the whole journey</p>
              <h2 className="section-title mx-auto">
                From a social media post to an organised order.
              </h2>
              <p className="section-copy mx-auto">
                Click through the exact path your customer and business take. This is an interactive
                demonstration, not a static diagram.
              </p>
            </div>
            <div className="mx-auto mt-10 flex max-w-2xl rounded-2xl bg-[#edf0ea] p-1.5">
              {["1. Discover", "2. Shop", "3. Sell"].map((s, i) => (
                <button
                  key={s}
                  onClick={() => setStage(i)}
                  className={`flex-1 rounded-xl px-3 py-3 text-xs font-extrabold transition ${stage === i ? "bg-white shadow-sm" : "text-[#68766f]"}`}
                >
                  {s}
                </button>
              ))}
            </div>
            <div className="mt-7 grid min-h-[560px] items-center overflow-hidden rounded-[32px] bg-[#172b25] p-6 text-white sm:p-10 lg:grid-cols-2 lg:p-14">
              <div className="max-w-md">
                <span className="text-xs font-extrabold uppercase tracking-[.2em] text-[#b9dc92]">
                  Stage {stage + 1}
                </span>
                <h3 className="mt-4 text-4xl font-extrabold tracking-[-.05em]">
                  {stage === 0
                    ? "Attention starts the journey."
                    : stage === 1
                      ? "Interest becomes intent."
                      : "A chat becomes an order."}
                </h3>
                <p className="mt-5 leading-7 text-white/60">
                  {stage === 0
                    ? "A customer sees a product they like in their social feed. The product link opens the exact item, not a generic homepage."
                    : stage === 1
                      ? "They can see the real price, choose their size and colour, then add it to a structured cart."
                      : "The seller receives all the information needed to confirm, prepare and complete the order."}
                </p>
                <button
                  onClick={() =>
                    stage === 0 ? go("store", 1) : stage === 1 ? go("store", 1) : go("studio")
                  }
                  className="mt-7 flex items-center gap-2 rounded-full bg-[#e7f2d8] px-6 py-3.5 text-xs font-extrabold text-[#172b25]"
                >
                  {stage === 0
                    ? "Click the product link"
                    : stage === 1
                      ? "Configure the product"
                      : "Open Seller Studio"}{" "}
                  <Icon name="arrow" size={15} />
                </button>
              </div>
              <div className="mx-auto mt-10 w-full max-w-[330px] lg:mt-0">
                {stage === 0 ? (
                  <SocialPost shop={() => go("store", 1)} />
                ) : stage === 1 ? (
                  <div className="rounded-[24px] bg-white p-4 text-[#172b25] shadow-2xl">
                    <img
                      src={products[0].images[0]}
                      className="h-64 w-full rounded-2xl object-cover object-top"
                      alt=""
                    />
                    <b className="mt-4 block">{products[0].name}</b>
                    <span className="text-sm">{money(products[0].price)}</span>
                    <div className="mt-3 flex gap-2">
                      {["S", "M", "L"].map((x) => (
                        <span
                          key={x}
                          className={`grid h-8 w-8 place-items-center rounded-lg border text-[10px] font-bold ${x === "M" ? "border-[#172b25] bg-[#edf2e8]" : "border-black/10"}`}
                        >
                          {x}
                        </span>
                      ))}
                    </div>
                    <button
                      onClick={() => go("store", 1)}
                      className="mt-4 w-full rounded-full bg-[#172b25] py-3 text-xs font-bold text-white"
                    >
                      Continue in storefront
                    </button>
                  </div>
                ) : (
                  <div className="rounded-[24px] bg-white p-5 text-[#172b25] shadow-2xl">
                    <div className="flex justify-between">
                      <div>
                        <small className="text-[#748079]">Order #MF-2048</small>
                        <b className="block">Wanjiku Kamau</b>
                      </div>
                      <StatusPill status="NEW" />
                    </div>
                    <div className="my-5 border-t border-black/5" />
                    <div className="flex gap-3">
                      <img
                        src={products[0].images[0]}
                        className="h-16 w-14 rounded-lg object-cover object-top"
                        alt=""
                      />
                      <div>
                        <b className="text-xs">{products[0].name}</b>
                        <p className="mt-1 text-[10px] text-[#748079]">Forest • M • Qty 1</p>
                        <b className="text-xs">{money(products[0].price)}</b>
                      </div>
                    </div>
                    <button
                      onClick={() => go("studio")}
                      className="mt-5 w-full rounded-full bg-[#172b25] py-3 text-xs font-bold text-white"
                    >
                      Manage order
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        </section>

        <section id="features" className="bg-[#eef1e7] px-5 py-24 sm:px-8">
          <div className="mx-auto max-w-[1180px]">
            <p className="eyebrow">One connected workspace</p>
            <h2 className="section-title">Everything between “I want it” and “It’s delivered.”</h2>
            <div className="mt-12 grid gap-4 md:grid-cols-3">
              {[
                [
                  "grid",
                  "A store that feels yours",
                  "Products, variations, stock and shareable links in one mobile storefront.",
                ],
                [
                  "order",
                  "Orders without the chaos",
                  "Every detail captured and every status visible to seller and customer.",
                ],
                [
                  "chart",
                  "Decisions from real activity",
                  "Understand products, orders and customers with simple, honest analytics.",
                ],
              ].map(([i, t, b]) => (
                <article key={t} className="rounded-[24px] bg-white p-7">
                  <span className="grid h-11 w-11 place-items-center rounded-xl bg-[#e7f1dc] text-[#315f46]">
                    <Icon name={i} />
                  </span>
                  <h3 className="mt-10 text-xl font-extrabold">{t}</h3>
                  <p className="mt-3 text-sm leading-6 text-[#68766f]">{b}</p>
                </article>
              ))}
            </div>
          </div>
        </section>
        <section className="px-5 py-24 sm:px-8">
          <div className="mx-auto max-w-[1180px] rounded-[34px] bg-[#e8743c] px-7 py-16 text-center text-white">
            <p className="text-xs font-extrabold uppercase tracking-[.18em] text-white/70">
              Your next customer is already online
            </p>
            <h2 className="mx-auto mt-4 max-w-3xl text-4xl font-extrabold tracking-[-.05em] sm:text-6xl">
              Give every click a clear next step.
            </h2>
            <button
              onClick={builder}
              className="mt-8 rounded-full bg-white px-7 py-4 text-sm font-extrabold text-[#172b25]"
            >
              Build a demo store
            </button>
          </div>
        </section>
      </main>
      <footer className="border-t border-black/5 px-5 py-8">
        <div className="mx-auto flex max-w-[1180px] flex-col items-center justify-between gap-4 sm:flex-row">
          <Logo />
          <p className="text-[10px] text-[#748079]">
            Interactive prototype • No live payments are processed
          </p>
          <div className="flex gap-5 text-xs font-bold">
            <button onClick={() => go("store")}>Store</button>
            <button onClick={() => go("studio")}>Studio</button>
            <button onClick={() => go("tracking")}>Track</button>
          </div>
        </div>
      </footer>
    </div>
  );
}

function ProductModal({
  product,
  close,
  add,
  share,
}: {
  product: Product;
  close: () => void;
  add: (item: CartItem) => void;
  share: () => void;
}) {
  const [photo, setPhoto] = useState(0);
  const [size, setSize] = useState("");
  const [color, setColor] = useState("");
  const [qty, setQty] = useState(1);
  const [error, setError] = useState("");
  const [added, setAdded] = useState(false);
  const submit = () => {
    if (!size || !color) {
      setError(
        `Choose a ${!size && !color ? "size and colour" : !size ? "size" : "colour"} first.`,
      );
      return;
    }
    add({ productId: product.id, size, color, qty });
    setAdded(true);
    window.setTimeout(() => setAdded(false), 1400);
  };
  return (
    <>
      <button
        className="fixed inset-0 z-50 bg-[#172b25]/55 backdrop-blur-sm"
        onClick={close}
        aria-label="Close product"
      />
      <div className="fixed inset-x-0 bottom-0 z-[60] max-h-[94vh] overflow-auto rounded-t-[30px] bg-[#fffdf9] shadow-2xl md:left-1/2 md:top-1/2 md:bottom-auto md:max-w-[940px] md:-translate-x-1/2 md:-translate-y-1/2 md:rounded-[30px]">
        <button
          onClick={close}
          className="absolute right-4 top-4 z-10 rounded-full bg-white/90 p-2 shadow"
        >
          <Icon name="close" size={18} />
        </button>
        <div className="grid md:grid-cols-[1.05fr_.95fr]">
          <div className="bg-[#ecebe5] p-3 sm:p-5">
            <img
              src={product.images[photo]}
              className="h-[330px] w-full rounded-2xl object-cover object-top sm:h-[500px]"
              alt={product.name}
            />
            <div className="mt-3 flex gap-2">
              {product.images.map((x, i) => (
                <button
                  key={x}
                  onClick={() => setPhoto(i)}
                  className={`overflow-hidden rounded-xl border-2 ${photo === i ? "border-[#172b25]" : "border-transparent"}`}
                >
                  <img src={x} className="h-16 w-14 object-cover object-top" alt="" loading="lazy" />
                </button>
              ))}
            </div>
          </div>
          <div className="p-6 sm:p-9">
            <div className="flex items-start justify-between gap-4">
              <div>
                <small className="font-bold uppercase tracking-[.15em] text-[#e06a38]">
                  {product.category}
                </small>
                <h2 className="mt-2 text-3xl font-black tracking-[-.04em]">{product.name}</h2>
                <p className="mt-2 text-xl font-extrabold">{money(product.price)}</p>
              </div>
              <button
                onClick={share}
                className="mt-7 rounded-full border border-black/10 p-2.5"
                aria-label="Copy product link"
              >
                <Icon name="share" size={17} />
              </button>
            </div>
            <p className="mt-5 text-sm leading-6 text-[#66746d]">{product.description}</p>
            <p className="mt-4 flex items-center gap-2 text-xs font-bold text-[#3b714f]">
              <span className="h-2 w-2 rounded-full bg-[#55a66e]" /> In stock • {product.stock}{" "}
              available
            </p>
            <div className="mt-7">
              <div className="flex justify-between">
                <b className="text-xs">Select size</b>
                <span className="text-[10px] text-[#748079]">Required</span>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                {product.sizes.map((s) => (
                  <button
                    key={s}
                    onClick={() => {
                      setSize(s);
                      setError("");
                    }}
                    className={`min-w-10 rounded-xl border px-3 py-2.5 text-xs font-bold ${size === s ? "border-[#172b25] bg-[#172b25] text-white" : "border-black/10"}`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
            <div className="mt-6">
              <div className="flex justify-between">
                <b className="text-xs">Select colour</b>
                <span className="text-[10px] text-[#748079]">Required</span>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                {product.colors.map((c) => (
                  <button
                    key={c.name}
                    onClick={() => {
                      setColor(c.name);
                      setError("");
                    }}
                    className={`flex items-center gap-2 rounded-full border px-3 py-2 text-xs font-bold ${color === c.name ? "border-[#172b25] bg-[#edf1e9]" : "border-black/10"}`}
                  >
                    <span
                      className="h-4 w-4 rounded-full border border-black/10"
                      style={{ background: c.hex }}
                    />
                    {c.name}
                  </button>
                ))}
              </div>
            </div>
            <div className="mt-6 flex items-center justify-between">
              <b className="text-xs">Quantity</b>
              <div className="flex items-center gap-4 rounded-full border border-black/10 px-3 py-2">
                <button onClick={() => setQty(Math.max(1, qty - 1))}>
                  <Icon name="minus" size={14} />
                </button>
                <b className="text-xs">{qty}</b>
                <button onClick={() => setQty(Math.min(product.stock, qty + 1))}>
                  <Icon name="plus" size={14} />
                </button>
              </div>
            </div>
            {error && (
              <p className="mt-4 rounded-xl bg-[#fff0e8] px-3 py-2 text-xs font-bold text-[#bd562b]">
                {error}
              </p>
            )}
            <button
              onClick={submit}
              className="sticky bottom-3 mt-6 flex w-full items-center justify-center gap-2 rounded-full bg-[#172b25] py-4 text-sm font-extrabold text-white shadow-lg"
            >
              {added ? "Added ✓" : `Add to cart • ${money(product.price * qty)}`}
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

function CartDrawer({
  items,
  close,
  update,
  remove,
  checkout,
}: {
  items: CartItem[];
  close: () => void;
  update: (i: number, q: number) => void;
  remove: (i: number) => void;
  checkout: () => void;
}) {
  const total = items.reduce(
    (s, x) => s + products.find((p) => p.id === x.productId)!.price * x.qty,
    0,
  );
  return (
    <>
      <button
        className="fixed inset-0 z-50 bg-[#172b25]/45 backdrop-blur-sm animate-[fade-in_180ms_ease-out]"
        onClick={close}
        aria-label="Close cart"
      />
      <aside className="fixed inset-y-0 right-0 z-[60] flex w-full max-w-[440px] flex-col bg-[#fffdf9] p-6 shadow-2xl animate-[slide-in_220ms_ease-out]">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-black">Your cart</h2>
            <p className="text-[10px] text-[#748079]">
              {items.reduce((s, x) => s + x.qty, 0)} items selected
            </p>
          </div>
          <button onClick={close} className="rounded-full border border-black/10 p-2">
            <Icon name="close" size={18} />
          </button>
        </div>
        {items.length === 0 ? (
          <div className="grid flex-1 place-items-center text-center">
            <div>
              <span className="mx-auto grid h-14 w-14 place-items-center rounded-full bg-[#edf1e9]">
                <Icon name="cart" />
              </span>
              <b className="mt-4 block">Your cart is waiting</b>
              <p className="mt-2 text-xs text-[#748079]">
                Choose a product to begin your demo order.
              </p>
              <button onClick={close} className="mt-5 text-xs font-extrabold underline">
                Browse products
              </button>
            </div>
          </div>
        ) : (
          <>
            <div className="mt-7 flex-1 space-y-5 overflow-auto">
              {items.map((x, i) => {
                const p = products.find((y) => y.id === x.productId)!;
                return (
                  <div key={`${x.productId}-${x.size}-${x.color}`} className="flex gap-4">
                    <img
                      src={p.images[0]}
                      className="h-24 w-20 rounded-xl object-cover object-top"
                      alt=""
                    />
                    <div className="flex flex-1 flex-col justify-between py-1">
                      <div className="flex justify-between gap-3">
                        <div>
                          <b className="block text-xs">{p.name}</b>
                          <small className="text-[10px] text-[#748079]">
                            {x.color} • Size {x.size}
                          </small>
                        </div>
                        <b className="text-xs">{money(p.price * x.qty)}</b>
                      </div>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3 rounded-full border border-black/10 px-2 py-1">
                          <button onClick={() => update(i, x.qty - 1)} className="transition active:scale-90 hover:text-[#bd562b]">
                            <Icon name="minus" size={13} />
                          </button>
                          <b className="text-[10px]">{x.qty}</b>
                          <button onClick={() => update(i, x.qty + 1)}>
                            <Icon name="plus" size={13} />
                          </button>
                        </div>
                        <button
                          onClick={() => remove(i)}
                          className="text-[#a05234]"
                          aria-label="Remove item"
                        >
                          <Icon name="trash" size={15} />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="border-t border-black/10 pt-5">
              <div className="flex justify-between font-black">
                <span>Subtotal</span>
                <span>{money(total)}</span>
              </div>
              <p className="mt-1 text-[10px] text-[#748079]">
                Delivery is calculated in the next steps.
              </p>
              <button
                onClick={checkout}
                className="mt-5 w-full rounded-full bg-[#172b25] py-4 text-sm font-extrabold text-white"
              >
                Start demo checkout
              </button>
            </div>
          </>
        )}
      </aside>
    </>
  );
}

function Checkout({
  items,
  cancel,
  submit,
}: {
  items: CartItem[];
  cancel: () => void;
  submit: (d: Omit<DemoOrder, "ref" | "created" | "total" | "items">) => void;
}) {
  const [step, setStep] = useState(1);
  const [customer, setCustomer] = useState<Customer>({
    name: "Wanjiku Kamau",
    phone: "+254 712 345 678",
    email: "wanjiku@example.com",
    location: "Nairobi",
  });
  const [delivery, setDelivery] = useState<"Delivery" | "Store pickup">("Delivery");
  const [address, setAddress] = useState("Kilimani, Nairobi");
  const [payment, setPayment] = useState<"M-Pesa" | "Pay on delivery">("M-Pesa");
  const total =
    items.reduce((s, x) => s + products.find((p) => p.id === x.productId)!.price * x.qty, 0) +
    (delivery === "Delivery" ? 250 : 0);
  const next = (e?: React.FormEvent) => {
    e?.preventDefault();
    setStep(Math.min(4, step + 1));
    window.scrollTo(0, 0);
  };
  return (
    <div className="min-h-screen bg-[#f4f5f1]">
      <header className="border-b border-black/5 bg-white">
        <div className="mx-auto flex h-[70px] max-w-[980px] items-center justify-between px-5">
          <Logo />
          <button onClick={cancel} className="text-xs font-bold">
            Exit checkout
          </button>
        </div>
      </header>
      <main className="mx-auto max-w-[980px] px-5 py-8 sm:py-12">
        <div className="mb-8 flex items-center justify-center">
          {[1, 2, 3, 4].map((n, i) => (
            <div key={n} className="flex items-center">
              <span
                className={`grid h-8 w-8 place-items-center rounded-full text-[10px] font-black ${n <= step ? "bg-[#172b25] text-white" : "bg-white text-[#8b9690]"}`}
              >
                {n < step ? <Icon name="check" size={14} /> : n}
              </span>
              {i < 3 && (
                <span
                  className={`h-0.5 w-10 sm:w-20 ${n < step ? "bg-[#172b25]" : "bg-[#d9ded9]"}`}
                />
              )}
            </div>
          ))}
        </div>
        <div className="grid gap-7 lg:grid-cols-[1fr_320px]">
          <form onSubmit={next} className="rounded-[24px] bg-white p-6 shadow-sm sm:p-9">
            {step === 1 && (
              <>
                <p className="eyebrow">Step 1 of 4</p>
                <h1 className="mt-2 text-3xl font-black tracking-[-.04em]">Review your cart</h1>
                <div className="mt-7 space-y-4">
                  {items.map((x) => {
                    const p = products.find((y) => y.id === x.productId)!;
                    return (
                      <div
                        key={`${p.id}${x.size}${x.color}`}
                        className="flex items-center gap-4 rounded-2xl bg-[#f5f6f2] p-3"
                      >
                        <img
                          src={p.images[0]}
                          className="h-20 w-16 rounded-xl object-cover object-top"
                          alt=""
                        />
                        <div className="flex-1">
                          <b className="text-xs">{p.name}</b>
                          <p className="text-[10px] text-[#748079]">
                            {x.color} • {x.size} • Qty {x.qty}
                          </p>
                        </div>
                        <b className="text-xs">{money(p.price * x.qty)}</b>
                      </div>
                    );
                  })}
                </div>
              </>
            )}
            {step === 2 && (
              <>
                <p className="eyebrow">Step 2 of 4</p>
                <h1 className="mt-2 text-3xl font-black tracking-[-.04em]">Your details</h1>
                <p className="mt-2 text-sm text-[#68766f]">
                  The store uses these details to confirm your order.
                </p>
                <div className="mt-7 grid gap-4 sm:grid-cols-2">
                  <label className="label sm:col-span-2">
                    Full name
                    <input
                      required
                      className="field mt-2"
                      value={customer.name}
                      onChange={(e) => setCustomer({ ...customer, name: e.target.value })}
                    />
                  </label>
                  <label className="label">
                    Phone number
                    <input
                      required
                      className="field mt-2"
                      value={customer.phone}
                      onChange={(e) => setCustomer({ ...customer, phone: e.target.value })}
                    />
                  </label>
                  <label className="label">
                    Email (optional)
                    <input
                      type="email"
                      className="field mt-2"
                      value={customer.email}
                      onChange={(e) => setCustomer({ ...customer, email: e.target.value })}
                    />
                  </label>
                  <label className="label sm:col-span-2">
                    Town or area
                    <input
                      required
                      className="field mt-2"
                      value={customer.location}
                      onChange={(e) => setCustomer({ ...customer, location: e.target.value })}
                    />
                  </label>
                </div>
              </>
            )}
            {step === 3 && (
              <>
                <p className="eyebrow">Step 3 of 4</p>
                <h1 className="mt-2 text-3xl font-black tracking-[-.04em]">Delivery method</h1>
                <div className="mt-7 grid gap-3 sm:grid-cols-2">
                  {(["Delivery", "Store pickup"] as const).map((d) => (
                    <button
                      type="button"
                      key={d}
                      onClick={() => setDelivery(d)}
                      className={`rounded-2xl border-2 p-5 text-left ${delivery === d ? "border-[#3d7558] bg-[#eef6e9]" : "border-black/10"}`}
                    >
                      <b className="text-sm">{d}</b>
                      <p className="mt-1 text-[10px] text-[#748079]">
                        {d === "Delivery"
                          ? "Nairobi delivery • KSh 250"
                          : "Collect from Kilimani • Free"}
                      </p>
                    </button>
                  ))}
                </div>
                {delivery === "Delivery" && (
                  <label className="label mt-5 block">
                    Delivery address
                    <input
                      required
                      className="field mt-2"
                      value={address}
                      onChange={(e) => setAddress(e.target.value)}
                    />
                  </label>
                )}
              </>
            )}
            {step === 4 && (
              <>
                <p className="eyebrow">Step 4 of 4</p>
                <h1 className="mt-2 text-3xl font-black tracking-[-.04em]">Payment arrangement</h1>
                <div className="mt-7 space-y-3">
                  {(["M-Pesa", "Pay on delivery"] as const).map((p) => (
                    <button
                      type="button"
                      key={p}
                      onClick={() => setPayment(p)}
                      className={`w-full rounded-2xl border-2 p-5 text-left ${payment === p ? "border-[#3d7558] bg-[#eef6e9]" : "border-black/10"}`}
                    >
                      <div className="flex justify-between">
                        <b className="text-sm">{p}</b>
                        <span
                          className={`h-4 w-4 rounded-full border ${payment === p ? "border-[5px] border-[#3d7558]" : "border-black/20"}`}
                        />
                      </div>
                      <p className="mt-1 text-[10px] text-[#748079]">
                        {p === "M-Pesa"
                          ? "The seller will confirm stock before sending a payment request."
                          : "Pay when your delivery arrives, where available."}
                      </p>
                    </button>
                  ))}
                </div>
                <div className="mt-5 rounded-xl bg-[#fff0e8] p-4 text-[10px] leading-5 text-[#8d4a2d]">
                  <b>Demonstration only.</b> No M-Pesa request or payment is processed. A payment is
                  never marked successful until a provider confirms it.
                </div>
              </>
            )}
            <div className="mt-8 flex items-center justify-between">
              {step > 1 ? (
                <button
                  type="button"
                  onClick={() => setStep(step - 1)}
                  className="flex items-center gap-1 text-xs font-bold"
                >
                  <Icon name="back" size={14} /> Back
                </button>
              ) : (
                <span />
              )}
              {step < 4 ? (
                <button className="rounded-full bg-[#172b25] px-6 py-3.5 text-xs font-extrabold text-white">
                  Continue
                </button>
              ) : (
                <button
                  type="button"
                  onClick={() =>
                    submit({
                      customer,
                      delivery,
                      address: delivery === "Delivery" ? address : "Urban Threads KE, Kilimani",
                      payment,
                    })
                  }
                  className="rounded-full bg-[#172b25] px-6 py-3.5 text-xs font-extrabold text-white"
                >
                  Submit demo order
                </button>
              )}
            </div>
          </form>
          <aside className="h-fit rounded-[24px] bg-[#172b25] p-6 text-white">
            <h2 className="font-extrabold">Order summary</h2>
            <div className="mt-5 space-y-3 text-xs">
              {items.map((x) => {
                const p = products.find((y) => y.id === x.productId)!;
                return (
                  <div
                    key={`${p.id}${x.size}`}
                    className="flex justify-between gap-3 text-white/65"
                  >
                    <span>
                      {p.name} × {x.qty}
                    </span>
                    <span>{money(p.price * x.qty)}</span>
                  </div>
                );
              })}
            </div>
            <div className="my-5 border-t border-white/10" />
            <div className="flex justify-between text-xs text-white/60">
              <span>Delivery</span>
              <span>{delivery === "Delivery" ? "KSh 250" : "Free"}</span>
            </div>
            <div className="mt-3 flex justify-between font-black">
              <span>Total</span>
              <span>{money(total)}</span>
            </div>
            <p className="mt-5 text-[9px] leading-4 text-white/40">
              This total is for a prototype order. No charge will be made.
            </p>
          </aside>
        </div>
      </main>
    </div>
  );
}

function Store({
  go,
  openProductId,
  clearProduct,
  cart,
  setCart,
  toast,
  submitOrder,
}: {
  go: (v: View, p?: number) => void;
  openProductId: number | null;
  clearProduct: () => void;
  cart: CartItem[];
  setCart: React.Dispatch<React.SetStateAction<CartItem[]>>;
  toast: (s: string) => void;
  submitOrder: (d: Omit<DemoOrder, "ref" | "created" | "total" | "items">) => void;
}) {
  const [category, setCategory] = useState("All");
  const [search, setSearch] = useState("");
  const [cartOpen, setCartOpen] = useState(false);
  const [checkout, setCheckout] = useState(false);
  const filtered = products.filter(
    (p) =>
      (category === "All" || p.category === category) &&
      p.name.toLowerCase().includes(search.toLowerCase()),
  );
  const share = (text: string) => {
    navigator.clipboard?.writeText(text);
    toast("Demo link copied to clipboard");
  };
  const add = (item: CartItem) => {
    setCart((c) => {
      const i = c.findIndex(
        (x) => x.productId === item.productId && x.size === item.size && x.color === item.color,
      );
      if (i < 0) return [...c, item];
      return c.map((x, n) => (n === i ? { ...x, qty: x.qty + item.qty } : x));
    });
    clearProduct();
    toast("Added to cart");
    setCartOpen(true);
  };
  if (checkout)
    return <Checkout items={cart} cancel={() => setCheckout(false)} submit={submitOrder} />;
  return (
    <div className="min-h-screen bg-[#fffdf9] text-[#172b25]">
      <div className="bg-[#172b25] py-2 text-center text-[10px] font-bold text-white">
        Interactive demo store • No live payments
      </div>
      <header className="sticky top-0 z-30 border-b border-black/5 bg-[#fffdf9]/95 backdrop-blur-xl">
        <div className="mx-auto flex h-[70px] max-w-[1180px] items-center justify-between px-5">
          <button
            onClick={() => go("home")}
            className="flex items-center gap-1 text-[10px] font-bold text-[#68766f]"
          >
            <Icon name="back" size={14} />
            <span className="hidden sm:inline">MtaaFlow</span>
          </button>
          <b className="absolute left-1/2 -translate-x-1/2 text-sm tracking-[.15em] sm:text-lg">
            URBAN THREADS KE
          </b>
          <div className="flex gap-2">
            <button
              onClick={() => share("https://mtaaflow.demo/urbanthreads")}
              className="hidden rounded-full border border-black/10 p-2.5 sm:block"
              aria-label="Copy store link"
            >
              <Icon name="share" size={17} />
            </button>
            <button
              onClick={() => setCartOpen(true)}
              className="relative rounded-full border border-black/10 p-2.5"
            >
              <Icon name="cart" size={17} />
              {cart.length > 0 && (
                <span key={cart.reduce((s, x) => s + x.qty, 0)} className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-[#e8743c] px-1 text-[9px] font-black text-white animate-[cart-pop_220ms_ease-out]">
                  {cart.reduce((s, x) => s + x.qty, 0)}
                </span>
              )}
            </button>
          </div>
        </div>
      </header>
      <section className="relative h-[440px] overflow-hidden sm:h-[560px]">
        <img
          src={products[3].images[0]}
          className="h-full w-full object-cover object-[center_25%]"
          alt="Urban Threads KE streetwear"
        />
        <span className="absolute inset-0 bg-gradient-to-r from-black/70 via-black/10 to-transparent" />
        <div className="absolute inset-0 mx-auto flex max-w-[1180px] items-end px-5 pb-10 sm:items-center sm:pb-0">
          <div className="max-w-lg text-white">
            <small className="font-black uppercase tracking-[.2em]">Nairobi / New drop</small>
            <h1 className="mt-3 text-5xl font-black leading-none tracking-[-.06em] sm:text-7xl">
              Built for the city.
            </h1>
            <p className="mt-4 max-w-sm text-sm leading-6 text-white/70">
              Independent Kenyan streetwear for wherever Nairobi takes you next.
            </p>
            <a
              href="#shop"
              className="mt-6 inline-block rounded-full bg-white px-6 py-3 text-xs font-extrabold text-[#172b25]"
            >
              Shop the drop
            </a>
          </div>
        </div>
      </section>
      <section id="shop" className="mx-auto max-w-[1180px] px-5 py-16">
        <div className="flex flex-col justify-between gap-5 lg:flex-row lg:items-end">
          <div>
            <p className="eyebrow">Urban Threads KE</p>
            <h2 className="mt-2 text-4xl font-black tracking-[-.05em]">The city collection</h2>
            <p className="mt-2 text-xs text-[#748079]">
              Nairobi, Kenya • Local delivery and pickup
            </p>
          </div>
          <div className="relative w-full lg:w-72">
            <Icon
              name="search"
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-[#748079]"
            />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full rounded-full border border-black/10 bg-white py-3 pl-10 pr-4 text-xs"
              placeholder="Search the collection..."
            />
          </div>
        </div>
        <div className="mt-7 flex gap-2 overflow-x-auto pb-2">
          {["All", ...new Set(products.map((p) => p.category))].map((c) => (
            <button
              key={c}
              onClick={() => setCategory(c)}
              className={`whitespace-nowrap rounded-full px-4 py-2 text-[10px] font-extrabold transition ${category === c ? "bg-[#172b25] text-white" : "border border-black/10 bg-white"}`}
            >
              {c}
            </button>
          ))}
        </div>
        {filtered.length ? (
          <div className="mt-7 grid grid-cols-2 gap-x-3 gap-y-9 md:grid-cols-3 lg:grid-cols-4">
            {filtered.map((p) => (
              <article key={p.id} className="group transition duration-200 hover:-translate-y-1">
                <button
                  onClick={() => go("store", p.id)}
                  className="relative block aspect-[.76] w-full overflow-hidden rounded-2xl bg-[#ecebe5] text-left"
                >
                  <img
                    src={p.images[0]}
                    className="h-full w-full object-cover object-top transition duration-500 group-hover:scale-105"
                    alt={p.name}
                  />
                  {p.stock <= 5 && (
                    <span className="absolute left-3 top-3 rounded-full bg-white px-2.5 py-1 text-[8px] font-black">
                      ONLY {p.stock} LEFT
                    </span>
                  )}
                  <span className="absolute bottom-3 right-3 grid h-10 w-10 place-items-center rounded-full bg-white shadow-lg">
                    <Icon name="plus" size={18} />
                  </span>
                </button>
                <div className="pt-3">
                  <div className="flex justify-between gap-2">
                    <button
                      onClick={() => go("store", p.id)}
                      className="text-left text-xs font-extrabold sm:text-sm"
                    >
                      {p.name}
                    </button>
                    <b className="whitespace-nowrap text-xs">{money(p.price)}</b>
                  </div>
                  <div className="mt-2 flex items-center justify-between">
                    <span className="text-[9px] text-[#748079]">
                      {p.colors.length} colours • {p.sizes.length} sizes
                    </span>
                    <button
                      onClick={() => share(`https://mtaaflow.demo/urbanthreads/product/${p.id}`)}
                      className="text-[#6c7972]"
                      aria-label={`Copy link for ${p.name}`}
                    >
                      <Icon name="link" size={14} />
                    </button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        ) : (
          <div className="mt-14 rounded-2xl bg-[#f3f4f0] p-10 text-center">
            <b>No products found</b>
            <p className="mt-2 text-xs text-[#748079]">Try a different search or category.</p>
            <button
              onClick={() => {
                setSearch("");
                setCategory("All");
              }}
              className="mt-4 text-xs font-bold underline"
            >
              Clear filters
            </button>
          </div>
        )}
      </section>
      <section className="bg-[#edf1e9] px-5 py-10">
        <div className="mx-auto flex max-w-[880px] flex-col justify-between gap-4 text-center text-xs font-bold sm:flex-row">
          <span>Made in Nairobi</span>
          <span>Delivery or Kilimani pickup</span>
          <button
            onClick={() => share("WhatsApp-ready Urban Threads store link")}
            className="flex items-center justify-center gap-2"
          >
            <Icon name="whatsapp" size={16} /> Share on WhatsApp
          </button>
        </div>
      </section>
      <footer className="py-8 text-center text-[10px] text-[#748079]">
        Powered by{" "}
        <button onClick={() => go("home")} className="font-black text-[#172b25]">
          MtaaFlow
        </button>
      </footer>
      {openProductId && (
        <ProductModal
          product={products.find((p) => p.id === openProductId)!}
          close={clearProduct}
          add={add}
          share={() => share(`https://mtaaflow.demo/urbanthreads/product/${openProductId}`)}
        />
      )}
      {cartOpen && (
        <CartDrawer
          items={cart}
          close={() => setCartOpen(false)}
          update={(i, q) =>
            q < 1
              ? setCart((c) => c.filter((_, n) => n !== i))
              : setCart((c) => c.map((x, n) => (n === i ? { ...x, qty: Math.min(9, q) } : x)))
          }
          remove={(i) => {
            setCart((c) => c.filter((_, n) => n !== i));
            toast("Item removed");
          }}
          checkout={() => {
            setCartOpen(false);
            setCheckout(true);
          }}
        />
      )}
    </div>
  );
}

const seededOrders = [
  {
    ref: "MF-2047",
    name: "Amina Noor",
    product: "Matatu Type Tee × 2",
    total: "KSh 3,700",
    status: "CONFIRMED" as Status,
    date: "Today, 09:42",
  },
  {
    ref: "MF-2046",
    name: "Brian Otieno",
    product: "CBD Utility Cargo",
    total: "KSh 3,600",
    status: "PAID" as Status,
    date: "Yesterday",
  },
  {
    ref: "MF-2045",
    name: "Mercy Njeri",
    product: "City Runner Jacket",
    total: "KSh 5,800",
    status: "PREPARING" as Status,
    date: "Yesterday",
  },
  {
    ref: "MF-2044",
    name: "Kevin Maina",
    product: "Nairobi Nights Hoodie",
    total: "KSh 4,200",
    status: "COMPLETED" as Status,
    date: "16 May",
  },
];

function Analytics() {
  const [range, setRange] = useState("30 days");
  const values =
    range === "7 days"
      ? [35, 48, 42, 65, 58, 82, 74]
      : range === "30 days"
        ? [42, 55, 39, 70, 64, 84, 76, 92, 68, 88, 100, 86]
        : [28, 41, 52, 48, 65, 72, 69, 81, 87, 91, 96, 100];
  return (
    <div>
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
        <div>
          <p className="text-xs text-[#748079]">Clearly labelled demonstration data</p>
          <h1 className="mt-1 text-3xl font-black tracking-[-.04em]">Analytics</h1>
        </div>
        <div className="flex rounded-full bg-white p-1">
          {["7 days", "30 days", "90 days"].map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`rounded-full px-4 py-2 text-[9px] font-black ${range === r ? "bg-[#172b25] text-white" : ""}`}
            >
              {r}
            </button>
          ))}
        </div>
      </div>
      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        {[
          ["Demo sales", "KSh 42,850"],
          ["Orders", "18"],
          ["Returning customers", "31%"],
        ].map(([a, b]) => (
          <div key={a} className="rounded-2xl bg-white p-5">
            <small className="text-[#748079]">{a}</small>
            <b className="mt-2 block text-2xl">{b}</b>
            <span className="text-[9px] text-[#3d7558]">Sample data</span>
          </div>
        ))}
      </div>
      <div className="mt-4 grid gap-4 lg:grid-cols-[1.4fr_.6fr]">
        <div className="rounded-[24px] bg-white p-6">
          <div className="flex justify-between">
            <b className="text-sm">Orders over time</b>
            <small className="text-[#748079]">{range}</small>
          </div>
          <div className="mt-8 flex h-52 items-end gap-2">
            {values.map((v, i) => (
              <div key={i} className="group relative flex-1">
                <span className="absolute -top-6 left-1/2 hidden -translate-x-1/2 text-[8px] font-bold group-hover:block">
                  {Math.round(v / 10)} orders
                </span>
                <div
                  className="rounded-t-md bg-[#9bc277] transition-all hover:bg-[#e8743c]"
                  style={{ height: `${v * 1.8}px` }}
                />
              </div>
            ))}
          </div>
        </div>
        <div className="rounded-[24px] bg-white p-6">
          <b className="text-sm">Order status</b>
          <div className="mt-7 space-y-4">
            {[
              ["Completed", 44, "#79a45c"],
              ["Preparing", 28, "#e8743c"],
              ["New", 17, "#d4b661"],
              ["Confirmed", 11, "#8c9a93"],
            ].map(([n, v, c]) => (
              <div key={String(n)}>
                <div className="flex justify-between text-[10px]">
                  <span>{n}</span>
                  <b>{v}%</b>
                </div>
                <div className="mt-1 h-2 rounded-full bg-[#edf0ea]">
                  <div
                    className="h-full rounded-full"
                    style={{ width: `${v}%`, background: String(c) }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
      <div className="mt-4 rounded-[24px] bg-white p-6">
        <b className="text-sm">Best-selling products</b>
        <div className="mt-5 grid gap-3 sm:grid-cols-3">
          {products.slice(0, 3).map((p, i) => (
            <div key={p.id} className="flex items-center gap-3 rounded-xl bg-[#f5f6f2] p-3">
              <img
                src={p.images[0]}
                className="h-12 w-10 rounded-lg object-cover object-top"
                alt=""
              />
              <div>
                <b className="block text-[10px]">{p.name}</b>
                <small className="text-[#748079]">{[8, 6, 5][i]} demo orders</small>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Studio({
  go,
  order,
  status,
  setStatus,
}: {
  go: (v: View) => void;
  order: DemoOrder | null;
  status: Status;
  setStatus: (s: Status) => void;
}) {
  const [page, setPage] = useState<StudioPage>("Overview");
  const [filter, setFilter] = useState<Status | "ALL">("ALL");
  const [selected, setSelected] = useState(order?.ref || "MF-2047");
  const [mobileNav, setMobileNav] = useState(false);
  useEffect(() => {
    if (order) setSelected(order.ref);
  }, [order]);
  const newRow = order
    ? {
        ref: order.ref,
        name: order.customer.name,
        product: order.items
          .map((x) => `${products.find((p) => p.id === x.productId)!.name} × ${x.qty}`)
          .join(", "),
        total: money(order.total),
        status,
        date: "Just now",
      }
    : null;
  const rows = [...(newRow ? [newRow] : []), ...seededOrders].filter(
    (x) => filter === "ALL" || x.status === filter,
  );
  const isNew = order && selected === order.ref;
  const nav: { n: StudioPage; i: string }[] = [
    { n: "Overview", i: "grid" },
    { n: "Orders", i: "order" },
    { n: "Products", i: "cart" },
    { n: "Customers", i: "user" },
    { n: "Analytics", i: "chart" },
    { n: "Store settings", i: "settings" },
  ];
  return (
    <div className="min-h-screen bg-[#f4f5f1] text-[#172b25]">
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-[235px] bg-[#172b25] p-5 text-white transition-transform lg:translate-x-0 ${mobileNav ? "translate-x-0" : "-translate-x-full"}`}
      >
        <div className="flex justify-between">
          <Logo light onClick={() => go("home")} />
          <button onClick={() => setMobileNav(false)} className="lg:hidden">
            <Icon name="close" />
          </button>
        </div>
        <div className="mt-9 space-y-1">
          {nav.map((x) => (
            <button
              key={x.n}
              onClick={() => {
                setPage(x.n);
                setMobileNav(false);
              }}
              className={`flex w-full items-center gap-3 rounded-xl px-3 py-3 text-xs font-bold ${page === x.n ? "bg-white/12 text-white" : "text-white/50"}`}
            >
              <Icon name={x.i} size={17} />
              {x.n}
              {x.n === "Orders" && order && (
                <span className="ml-auto grid h-5 w-5 place-items-center rounded-full bg-[#e8743c] text-[8px]">
                  1
                </span>
              )}
            </button>
          ))}
        </div>
        <div className="mt-auto absolute bottom-5 inset-x-5 rounded-xl bg-white/8 p-3">
          <b className="text-xs">Urban Threads KE</b>
          <p className="mt-1 text-[9px] text-white/40">Demo workspace</p>
        </div>
      </aside>
      {mobileNav && (
        <button
          className="fixed inset-0 z-30 bg-black/30 lg:hidden"
          onClick={() => setMobileNav(false)}
        />
      )}
      <main className="lg:ml-[235px]">
        <header className="flex h-[70px] items-center justify-between border-b border-black/5 bg-white px-5 sm:px-8">
          <button onClick={() => setMobileNav(true)} className="lg:hidden">
            <Icon name="menu" />
          </button>
          <div className="hidden lg:block">
            <b className="text-sm">Seller Studio</b>
            <p className="text-[9px] text-[#748079]">Interactive demonstration workspace</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => go("store")}
              className="rounded-full border border-black/10 px-4 py-2 text-[10px] font-bold"
            >
              View store
            </button>
            <button
              onClick={() => go("tracking")}
              className="hidden rounded-full border border-black/10 px-4 py-2 text-[10px] font-bold sm:block"
            >
              Customer tracking
            </button>
            <span className="grid h-9 w-9 place-items-center rounded-full bg-[#dce9cf] text-[10px] font-black">
              UT
            </span>
          </div>
        </header>
        <div className="p-4 sm:p-7 lg:p-9">
          {page === "Analytics" ? (
            <Analytics />
          ) : page === "Overview" ? (
            <>
              <div>
                <p className="text-xs text-[#748079]">Monday, 18 May • Demonstration data</p>
                <h1 className="mt-1 text-3xl font-black tracking-[-.04em]">
                  Good morning, Urban Threads.
                </h1>
              </div>
              <div className="mt-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
                {[
                  ["18", "Total orders"],
                  [order ? "4" : "3", "Pending orders"],
                  ["11", "Completed"],
                  ["KSh 42.8K", "Demo sales"],
                ].map(([v, l], i) => (
                  <button
                    key={l}
                    onClick={() => i < 3 && setPage("Orders")}
                    className="rounded-2xl bg-white p-5 text-left shadow-sm"
                  >
                    <b className={`text-2xl ${i === 1 ? "text-[#e06a38]" : ""}`}>{v}</b>
                    <p className="mt-1 text-[10px] text-[#748079]">{l}</p>
                  </button>
                ))}
              </div>
              <div className="mt-5 grid gap-5 xl:grid-cols-[1.3fr_.7fr]">
                <div className="rounded-[24px] bg-white p-5">
                  <div className="flex justify-between">
                    <b className="text-sm">Recent orders</b>
                    <button onClick={() => setPage("Orders")} className="text-[10px] font-bold">
                      View all →
                    </button>
                  </div>
                  <div className="mt-4">
                    {[...(newRow ? [newRow] : []), ...seededOrders].slice(0, 4).map((r) => (
                      <button
                        key={r.ref}
                        onClick={() => {
                          setSelected(r.ref);
                          setPage("Orders");
                        }}
                        className="grid w-full grid-cols-[1fr_auto] items-center border-t border-black/5 py-3 text-left sm:grid-cols-[80px_1fr_90px]"
                      >
                        <span className="hidden text-[9px] font-bold text-[#748079] sm:block">
                          {r.ref}
                        </span>
                        <span>
                          <b className="block text-[11px]">{r.name}</b>
                          <small className="block max-w-[180px] truncate text-[9px] text-[#748079]">
                            {r.product}
                          </small>
                        </span>
                        <StatusPill status={r.status} />
                      </button>
                    ))}
                  </div>
                </div>
                <div className="rounded-[24px] bg-[#172b25] p-6 text-white">
                  <div className="flex justify-between">
                    <b className="text-sm">Recent activity</b>
                    <Icon name="spark" size={17} className="text-[#b9dc92]" />
                  </div>
                  <div className="mt-6 space-y-6">
                    {[
                      order
                        ? `${order.ref} received from ${order.customer.name}`
                        : "A new order was received",
                      "CBD Utility Cargo marked paid",
                      "Matatu Type Tee stock updated",
                    ].map((t, i) => (
                      <div key={t} className="flex gap-3">
                        <span className="mt-1.5 h-2 w-2 rounded-full bg-[#b9dc92]" />
                        <div>
                          <p className="text-[10px]">{t}</p>
                          <small className="text-[8px] text-white/40">
                            {i === 0 && order ? "Just now" : `${i + 1}h ago`} • Demo
                          </small>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </>
          ) : page === "Orders" ? (
            <div>
              <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
                <div>
                  <p className="text-xs text-[#748079]">Connected to the demo storefront</p>
                  <h1 className="mt-1 text-3xl font-black tracking-[-.04em]">Orders</h1>
                </div>
                <div className="flex gap-1 overflow-x-auto rounded-full bg-white p-1">
                  {(["ALL", "NEW", "CONFIRMED", "PAID", "PREPARING", "COMPLETED"] as const).map(
                    (f) => (
                      <button
                        key={f}
                        onClick={() => setFilter(f)}
                        className={`rounded-full px-3 py-2 text-[8px] font-black ${filter === f ? "bg-[#172b25] text-white" : ""}`}
                      >
                        {f}
                      </button>
                    ),
                  )}
                </div>
              </div>
              <div className="mt-6 grid overflow-hidden rounded-[24px] bg-white shadow-sm xl:grid-cols-[1fr_370px]">
                <div>
                  {rows.map((r) => (
                    <button
                      key={r.ref}
                      onClick={() => setSelected(r.ref)}
                      className={`grid w-full grid-cols-[1fr_auto] items-center gap-2 border-b border-black/5 p-4 text-left sm:grid-cols-[75px_1.2fr_1fr_80px_90px] ${selected === r.ref ? "bg-[#f0f5eb]" : ""}`}
                    >
                      <span className="hidden text-[9px] font-bold text-[#748079] sm:block">
                        {r.ref}
                      </span>
                      <span>
                        <b className="block text-[11px]">{r.name}</b>
                        <small className="text-[8px] text-[#748079]">{r.date}</small>
                      </span>
                      <span className="hidden truncate text-[9px] text-[#64736c] sm:block">
                        {r.product}
                      </span>
                      <b className="hidden text-[10px] sm:block">{r.total}</b>
                      <StatusPill status={r.status} />
                    </button>
                  ))}
                  {rows.length === 0 && (
                    <div className="p-12 text-center">
                      <b>No matching orders</b>
                      <p className="mt-2 text-xs text-[#748079]">Try another status filter.</p>
                    </div>
                  )}
                </div>
                <aside className="border-l border-black/5 p-6">
                  {isNew ? (
                    <OrderDetail
                      order={order!}
                      status={status}
                      setStatus={setStatus}
                      track={() => go("tracking")}
                    />
                  ) : (
                    <div>
                      <small className="text-[#748079]">{selected}</small>
                      <h3 className="mt-1 text-lg font-black">
                        {seededOrders.find((x) => x.ref === selected)?.name || "Select an order"}
                      </h3>
                      <p className="mt-5 text-xs text-[#748079]">
                        Seeded demonstration order. Create an order in the storefront to see live
                        connected details and status updates here.
                      </p>
                    </div>
                  )}
                </aside>
              </div>
            </div>
          ) : page === "Products" ? (
            <div>
              <h1 className="text-3xl font-black">Products</h1>
              <p className="mt-1 text-xs text-[#748079]">Demo catalogue inventory</p>
              <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                {products.map((p) => (
                  <div key={p.id} className="flex gap-3 rounded-2xl bg-white p-3">
                    <img
                      src={p.images[0]}
                      className="h-20 w-16 rounded-xl object-cover object-top"
                      alt=""
                    />
                    <div className="flex-1 py-1">
                      <b className="text-xs">{p.name}</b>
                      <p className="mt-1 text-[9px] text-[#748079]">
                        {p.category} • {p.stock} in stock
                      </p>
                      <b className="mt-3 block text-[10px]">{money(p.price)}</b>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <EmptyStudio page={page} />
          )}
        </div>
      </main>
    </div>
  );
}

function OrderDetail({
  order,
  status,
  setStatus,
  track,
}: {
  order: DemoOrder;
  status: Status;
  setStatus: (s: Status) => void;
  track: () => void;
}) {
  const steps: Status[] = ["NEW", "CONFIRMED", "PAID", "PREPARING", "COMPLETED"];
  return (
    <div>
      <div className="flex justify-between">
        <div>
          <small className="text-[#748079]">{order.ref} • Just now</small>
          <h3 className="mt-1 text-lg font-black">{order.customer.name}</h3>
          <p className="text-[10px] text-[#748079]">{order.customer.phone}</p>
        </div>
        <StatusPill status={status} />
      </div>
      <div className="my-5 border-t border-black/5" />
      <b className="text-xs">Order details</b>
      <div className="mt-3 space-y-3">
        {order.items.map((x) => {
          const p = products.find((y) => y.id === x.productId)!;
          return (
            <div key={`${p.id}${x.size}`} className="flex gap-3">
              <img
                src={p.images[0]}
                className="h-14 w-12 rounded-lg object-cover object-top"
                alt=""
              />
              <div>
                <b className="text-[10px]">{p.name}</b>
                <p className="text-[9px] text-[#748079]">
                  {x.color} • {x.size} • Qty {x.qty}
                </p>
                <b className="text-[10px]">{money(p.price * x.qty)}</b>
              </div>
            </div>
          );
        })}
      </div>
      <div className="mt-5 rounded-xl bg-[#f4f5f1] p-3 text-[10px]">
        <div className="flex justify-between">
          <span className="text-[#748079]">{order.delivery}</span>
          <b className="text-right">{order.address}</b>
        </div>
        <div className="mt-2 flex justify-between">
          <span className="text-[#748079]">Payment</span>
          <b>{order.payment} • Demo pending</b>
        </div>
        <div className="mt-2 flex justify-between">
          <span className="text-[#748079]">Total</span>
          <b>{money(order.total)}</b>
        </div>
      </div>
      <b className="mt-6 block text-xs">Update fulfilment status</b>
      <div className="mt-3 grid grid-cols-2 gap-2">
        {steps.map((s) => (
          <button
            key={s}
            onClick={() => setStatus(s)}
            className={`rounded-xl border px-2 py-2 text-[9px] font-bold ${status === s ? "border-[#3d7558] bg-[#edf4e5] text-[#315f46]" : "border-black/10"}`}
          >
            {s}
          </button>
        ))}
      </div>
      {status === "PAID" && (
        <p className="mt-3 rounded-xl bg-[#fff0e8] p-3 text-[9px] leading-4 text-[#8d4a2d]">
          Demo status only. In production, “Paid” requires payment-provider confirmation.
        </p>
      )}
      <button
        onClick={track}
        className="mt-4 w-full rounded-full bg-[#172b25] py-3 text-[10px] font-bold text-white"
      >
        View customer tracking
      </button>
    </div>
  );
}

function EmptyStudio({ page }: { page: StudioPage }) {
  const content: Record<string, [string, string]> = {
    Customers: [
      "Customer directory",
      "Customer profiles will appear as demonstration orders are created.",
    ],
    "Store settings": [
      "Store settings",
      "Manage storefront details, delivery options and share links here.",
    ],
  };
  return (
    <div>
      <h1 className="text-3xl font-black">{page}</h1>
      <div className="mt-6 grid min-h-[420px] place-items-center rounded-[24px] bg-white p-8 text-center">
        <div>
          <span className="mx-auto grid h-14 w-14 place-items-center rounded-full bg-[#edf1e9]">
            <Icon name={page === "Customers" ? "user" : "settings"} />
          </span>
          <b className="mt-4 block">{content[page]?.[0]}</b>
          <p className="mx-auto mt-2 max-w-sm text-xs text-[#748079]">{content[page]?.[1]}</p>
        </div>
      </div>
    </div>
  );
}

function Tracking({
  go,
  order,
  status,
}: {
  go: (v: View) => void;
  order: DemoOrder | null;
  status: Status;
}) {
  const [ref, setRef] = useState(order?.ref || "");
  const [searched, setSearched] = useState(!!order);
  const [summaryCopied, setSummaryCopied] = useState(false);
  const steps = [
    ["NEW", "Order received", "Urban Threads KE has received your order."],
    ["CONFIRMED", "Order confirmed", "Stock and order details have been confirmed."],
    ["PAID", "Payment confirmed", "Payment provider confirmation received."],
    ["PREPARING", "Preparing order", "Your items are being prepared."],
    ["COMPLETED", "Completed", "Your order journey is complete."],
  ] as const;
  return (
    <div className="min-h-screen bg-[#f4f5f1]">
      <header className="border-b border-black/5 bg-white">
        <div className="mx-auto flex h-[70px] max-w-[1000px] items-center justify-between px-5">
          <Logo onClick={() => go("home")} />
          <div className="flex gap-2">
            <button onClick={() => go("store")} className="text-[10px] font-bold">
              Store
            </button>
            <button
              onClick={() => go("studio")}
              className="rounded-full bg-[#172b25] px-4 py-2 text-[10px] font-bold text-white"
            >
              Seller Studio
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-[800px] px-5 py-12 sm:py-20">
        <div className="text-center">
          <p className="eyebrow">Customer order tracking</p>
          <h1 className="mt-3 text-4xl font-black tracking-[-.05em] sm:text-5xl">
            {order ? "Your order is in motion." : "Track a demonstration order."}
          </h1>
          <p className="mx-auto mt-4 max-w-lg text-sm leading-6 text-[#68766f]">
            See the same status the seller manages in Seller Studio. Payment states in this
            prototype are demonstrations only.
          </p>
        </div>
        {!order ? (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              setSearched(true);
            }}
            className="mx-auto mt-8 flex max-w-lg gap-2 rounded-full bg-white p-2 shadow-sm"
          >
            <input
              value={ref}
              onChange={(e) => setRef(e.target.value)}
              required
              className="min-w-0 flex-1 bg-transparent px-4 text-xs outline-none"
              placeholder="Enter order reference, e.g. MF-2048"
            />
            <button className="rounded-full bg-[#172b25] px-5 py-3 text-[10px] font-bold text-white">
              Find order
            </button>
          </form>
        ) : (
          <div className="mt-8 rounded-[24px] bg-white p-5 shadow-sm sm:p-7">
            <div className="flex flex-col justify-between gap-4 border-b border-black/5 pb-5 sm:flex-row sm:items-center">
              <div>
                <small className="text-[#748079]">DEMONSTRATION ORDER</small>
                <h2 className="mt-1 text-xl font-black">{order.ref}</h2>
                <p className="text-[10px] text-[#748079]">
                  Placed {order.created} by {order.customer.name}
                </p>
              </div>
              <StatusPill status={status} />
            </div>
            <div className="mt-7">
              {steps.map(([s, title, body], i) => {
                const active = i <= statusIndex(status);
                const current = i === statusIndex(status);
                return (
                  <div key={s} className="relative flex gap-4 pb-7 last:pb-0">
                    <div className="relative z-10">
                      <span
                        className={`grid h-9 w-9 place-items-center rounded-full border-2 ${active ? "border-[#3d7558] bg-[#e4f2d9] text-[#315f46]" : "border-[#dce1dc] bg-white text-[#a5aea9]"}`}
                      >
                        {active ? <Icon name="check" size={15} /> : i + 1}
                      </span>
                      {i < 4 && (
                        <span
                          className={`absolute left-1/2 top-9 h-7 w-0.5 -translate-x-1/2 ${i < statusIndex(status) ? "bg-[#3d7558]" : "bg-[#dce1dc]"}`}
                        />
                      )}
                    </div>
                    <div className="pt-1">
                      <div className="flex items-center gap-2">
                        <b className={`text-xs ${active ? "" : "text-[#9ba59f]"}`}>{title}</b>
                        {current && (
                          <span className="rounded-full bg-[#fff0e8] px-2 py-0.5 text-[8px] font-black text-[#bd562b]">
                            CURRENT
                          </span>
                        )}
                      </div>
                      <p className="mt-1 text-[10px] text-[#748079]">{body}</p>
                      {s === "PAID" && current && (
                        <p className="mt-1 text-[9px] font-bold text-[#a05234]">
                          Demonstration state — not a verified real payment.
                        </p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="mt-7 border-t border-black/5 pt-6">
              <b className="text-xs">Order summary</b>
              <div className="mt-3 space-y-3">
                {order.items.map((item) => {
                  const product = products.find((candidate) => candidate.id === item.productId)!;
                  return (
                    <div
                      key={`${product.id}-${item.size}-${item.color}`}
                      className="flex items-center gap-3"
                    >
                      <img
                        src={product.images[0]}
                        className="h-14 w-12 rounded-lg object-cover object-top"
                        alt=""
                      />
                      <div className="min-w-0 flex-1">
                        <b className="block truncate text-[10px]">{product.name}</b>
                        <p className="text-[9px] text-[#748079]">
                          {item.color} • Size {item.size} • Qty {item.qty}
                        </p>
                      </div>
                      <b className="text-[10px]">{money(product.price * item.qty)}</b>
                    </div>
                  );
                })}
              </div>
            </div>
            <div className="mt-7 rounded-2xl bg-[#f5f6f2] p-4">
              <div className="flex justify-between text-xs">
                <span className="text-[#748079]">Delivery</span>
                <b>{order.delivery}</b>
              </div>
              <div className="mt-2 flex justify-between gap-5 text-xs">
                <span className="text-[#748079]">Deliver to</span>
                <b className="text-right">{order.address}</b>
              </div>
              <div className="mt-2 flex justify-between text-xs">
                <span className="text-[#748079]">Payment method</span>
                <b>{order.payment} • Demo</b>
              </div>
              <div className="mt-2 flex justify-between gap-5 text-xs">
                <span className="text-[#748079]">Customer</span>
                <b className="text-right">
                  {order.customer.name} • {order.customer.phone}
                </b>
              </div>
              <div className="mt-2 flex justify-between text-xs">
                <span className="text-[#748079]">Order total</span>
                <b>{money(order.total)}</b>
              </div>
            </div>
            <button
              onClick={() => {
                navigator.clipboard?.writeText(
                  `Urban Threads KE demo order ${order.ref}\nStatus: ${status}\nTotal: ${money(order.total)}\nTrack in MtaaFlow`,
                );
                setSummaryCopied(true);
                window.setTimeout(() => setSummaryCopied(false), 1800);
              }}
              className="mt-3 flex w-full items-center justify-center gap-2 rounded-full border border-black/10 py-3 text-[10px] font-bold"
            >
              <Icon name={summaryCopied ? "check" : "whatsapp"} size={15} />
              {summaryCopied ? "WhatsApp-ready summary copied" : "Copy WhatsApp order summary"}
            </button>
            <div className="mt-5 flex flex-col gap-2 sm:flex-row">
              <button
                onClick={() => go("store")}
                className="flex-1 rounded-full border border-black/10 py-3 text-[10px] font-bold"
              >
                Continue shopping
              </button>
              <button
                onClick={() => go("studio")}
                className="flex-1 rounded-full bg-[#172b25] py-3 text-[10px] font-bold text-white"
              >
                Update in Seller Studio
              </button>
            </div>
          </div>
        )}
        {!order && searched && (
          <div className="mx-auto mt-5 max-w-lg rounded-2xl bg-white p-5 text-center">
            <b className="text-sm">No demonstration order found</b>
            <p className="mt-2 text-xs text-[#748079]">
              Complete checkout in the Urban Threads store to generate a connected reference.
            </p>
            <button
              onClick={() => go("store")}
              className="mt-4 rounded-full bg-[#172b25] px-5 py-3 text-[10px] font-bold text-white"
            >
              Create a demo order
            </button>
          </div>
        )}
      </main>
    </div>
  );
}

function Builder({ close, finish }: { close: () => void; finish: () => void }) {
  const [step, setStep] = useState(1);
  const [name, setName] = useState("My Nairobi Store");
  const [category, setCategory] = useState("Fashion & clothing");
  const [style, setStyle] = useState("Editorial");
  return (
    <>
      <button
        className="fixed inset-0 z-50 bg-[#172b25]/60 backdrop-blur-md"
        onClick={close}
        aria-label="Close builder"
      />
      <div className="fixed left-1/2 top-1/2 z-[60] max-h-[92vh] w-[calc(100%-28px)] max-w-[620px] -translate-x-1/2 -translate-y-1/2 overflow-auto rounded-[28px] bg-[#fbfaf6] p-6 shadow-2xl sm:p-9">
        <div className="flex justify-between">
          <div>
            <p className="eyebrow">Store builder demo • {step}/5</p>
            <div className="mt-3 flex gap-1">
              {[1, 2, 3, 4, 5].map((i) => (
                <span
                  key={i}
                  className={`h-1.5 w-9 rounded-full ${i <= step ? "bg-[#172b25]" : "bg-[#dce1dc]"}`}
                />
              ))}
            </div>
          </div>
          <button onClick={close} className="rounded-full border border-black/10 p-2">
            <Icon name="close" size={16} />
          </button>
        </div>
        {step === 1 && (
          <div className="mt-8">
            <h2 className="text-3xl font-black tracking-[-.04em]">
              What should we call your store?
            </h2>
            <p className="mt-2 text-sm text-[#68766f]">
              No registration needed to explore this demonstration.
            </p>
            <label className="label mt-6 block">
              Business name
              <input
                autoFocus
                className="field mt-2"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </label>
          </div>
        )}
        {step === 2 && (
          <div className="mt-8">
            <h2 className="text-3xl font-black tracking-[-.04em]">What do you sell?</h2>
            <div className="mt-6 grid grid-cols-2 gap-3">
              {["Fashion & clothing", "Beauty & cosmetics", "Food & drinks", "Electronics"].map(
                (c) => (
                  <button
                    key={c}
                    onClick={() => setCategory(c)}
                    className={`rounded-2xl border-2 p-5 text-left text-xs font-bold ${category === c ? "border-[#3d7558] bg-[#eef6e9]" : "border-black/10"}`}
                  >
                    {c}
                  </button>
                ),
              )}
            </div>
          </div>
        )}
        {step === 3 && (
          <div className="mt-8">
            <h2 className="text-3xl font-black tracking-[-.04em]">Choose a storefront style.</h2>
            <div className="mt-6 grid grid-cols-3 gap-3">
              {[
                ["Editorial", "#e8743c"],
                ["Clean", "#315f46"],
                ["Warm", "#a77a58"],
              ].map(([s, c]) => (
                <button
                  key={s}
                  onClick={() => setStyle(s)}
                  className={`rounded-2xl border-2 p-2 text-left ${style === s ? "border-[#172b25]" : "border-transparent"}`}
                >
                  <div className="h-28 rounded-xl p-3" style={{ background: c }}>
                    <div className="h-2 w-10 rounded bg-white" />
                    <div className="mt-9 h-4 w-16 rounded bg-white/80" />
                  </div>
                  <b className="mt-2 block text-[10px]">{s}</b>
                </button>
              ))}
            </div>
          </div>
        )}
        {step === 4 && (
          <div className="mt-8">
            <h2 className="text-3xl font-black tracking-[-.04em]">Your store, generated.</h2>
            <div className="mt-6 overflow-hidden rounded-[22px] border-4 border-[#172b25] bg-white">
              <div className="flex justify-between p-3">
                <b className="text-xs uppercase">{name}</b>
                <Icon name="cart" size={15} />
              </div>
              <div className="relative h-52">
                <img
                  src={products[0].images[0]}
                  className="h-full w-full object-cover object-top"
                  alt=""
                />
                <span className="absolute inset-0 bg-black/25" />
                <b className="absolute bottom-4 left-4 text-xl text-white">{style} collection</b>
              </div>
              <div className="grid grid-cols-2 gap-2 p-3">
                {products.slice(1, 3).map((p) => (
                  <div key={p.id}>
                    <img
                      src={p.images[0]}
                      className="h-20 w-full rounded-lg object-cover object-top"
                      alt=""
                    />
                    <b className="mt-1 block truncate text-[8px]">{p.name}</b>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
        {step === 5 && (
          <div className="mt-8 text-center">
            <span className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-[#e4f2d9] text-[#315f46]">
              <Icon name="check" size={28} />
            </span>
            <h2 className="mt-5 text-3xl font-black tracking-[-.04em]">
              Your demo store is ready.
            </h2>
            <p className="mt-2 text-sm text-[#68766f]">
              {name} • {category} • {style}
            </p>
            <div className="mt-6 flex items-center justify-between rounded-2xl bg-white p-4 text-left">
              <div>
                <small className="text-[#748079]">DEMONSTRATION LINK</small>
                <b className="block text-xs">
                  mtaaflow.demo/{name.toLowerCase().replaceAll(" ", "-")}
                </b>
              </div>
              <Icon name="copy" size={17} />
            </div>
          </div>
        )}
        <div className="mt-8 flex justify-between">
          {step > 1 ? (
            <button onClick={() => setStep(step - 1)} className="text-xs font-bold">
              Back
            </button>
          ) : (
            <span />
          )}
          <button
            disabled={step === 1 && !name.trim()}
            onClick={() => (step < 5 ? setStep(step + 1) : finish())}
            className="flex items-center gap-2 rounded-full bg-[#172b25] px-6 py-3.5 text-xs font-extrabold text-white disabled:opacity-40"
          >
            {step < 5 ? "Continue" : "Explore live store"}
            <Icon name="arrow" size={14} />
          </button>
        </div>
      </div>
    </>
  );
}

export default function App() {
  const [view, setView] = useState<View>("home");
  const [productId, setProductId] = useState<number | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [order, setOrder] = useState<DemoOrder | null>(null);
  const [status, setStatusState] = useState<Status>("NEW");
  const [builder, setBuilder] = useState(false);
  const [toast, setToast] = useState("");
  const notify = (s: string) => {
    setToast(s);
    window.setTimeout(() => setToast(""), 2400);
  };
  const go = (v: View, p?: number) => {
    setView(v);
    setProductId(p || null);
    window.scrollTo(0, 0);
  };
  const submitOrder = (d: Omit<DemoOrder, "ref" | "created" | "total" | "items">) => {
    const total =
      cart.reduce((s, x) => s + products.find((p) => p.id === x.productId)!.price * x.qty, 0) +
      (d.delivery === "Delivery" ? 250 : 0);
    const next = {
      ...d,
      items: [...cart],
      total,
      ref: `MF-${Math.floor(2000 + Math.random() * 7000)}`,
      created: "18 May, 10:24",
    };
    setOrder(next);
    setStatusState("NEW");
    setCart([]);
    setView("tracking");
    notify("Demo order created and sent to Seller Studio");
  };
  const setStatus = (s: Status) => {
    setStatusState(s);
    notify(`Order updated to ${s.toLowerCase()}`);
  };
  useEffect(() => {
    document.title =
      view === "home"
        ? "MtaaFlow — Social commerce, organised"
        : view === "store"
          ? "Urban Threads KE"
          : view === "studio"
            ? "MtaaFlow Seller Studio"
            : "Track your MtaaFlow order";
  }, [view]);
  return (
    <>
      {view === "home" ? (
        <Landing go={go} builder={() => setBuilder(true)} />
      ) : view === "store" ? (
        <Store
          go={go}
          openProductId={productId}
          clearProduct={() => setProductId(null)}
          cart={cart}
          setCart={setCart}
          toast={notify}
          submitOrder={submitOrder}
        />
      ) : view === "studio" ? (
        <Studio go={go} order={order} status={status} setStatus={setStatus} />
      ) : (
        <Tracking go={go} order={order} status={status} />
      )}
      {builder && (
        <Builder
          close={() => setBuilder(false)}
          finish={() => {
            setBuilder(false);
            go("store");
            notify("Demo storefront generated");
          }}
        />
      )}
      {toast && (
        <div className="fixed bottom-5 left-1/2 z-[100] flex -translate-x-1/2 items-center gap-2 whitespace-nowrap rounded-full bg-[#172b25] px-5 py-3 text-[10px] font-bold text-white shadow-2xl">
          <Icon name="check" size={14} className="text-[#b9dc92]" />
          {toast}
        </div>
      )}
    </>
  );
}
