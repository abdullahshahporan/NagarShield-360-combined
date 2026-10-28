# Nagar Shield 360 — অফিসিয়াল ডেমো

Next.js ভিত্তিক বাংলাভাষী কর্মকর্তাদের ওয়েব ক্লায়েন্ট। `/` হলো একমাত্র উন্মুক্ত পাতা; নাগরিকের প্রতিবেদন জমা ও নিজের অবস্থা দেখার ব্যবস্থা শুধু পাশের `NagarShield App` Flutter ক্লায়েন্টে আছে। দুই ক্লায়েন্ট একই Supabase project ব্যবহার করে। সাইন ইন ছাড়া ড্যাশবোর্ড, মানচিত্র, ঘটনা, মিডিয়া ও প্রতিবেদন দেখা যায় না।

## চালু করার আগে

1. একটি **নতুন Supabase project** তৈরি করুন। Auth → Providers → Email-এ **Allow new users to sign up** বন্ধ করুন। Anonymous sign-ins-ও বন্ধ রাখুন।
2. নতুন project-এ এই ক্রমে SQL চালান: ওয়েবের `202610130001_prototype.sql`, `202610130002_reset_hotfix.sql`; Flutter-এর `supabase/mobile_extension.sql`, `mobile_extension_2.sql`; তারপর ওয়েবের `202610140001_survey_demo.sql`, `202610140002_bangla_copy.sql`। আগে থেকে থাকা project-এ migration history দেখে শুধু অনুপস্থিত ধাপ চালান। প্রথম migration দ্বিতীয়বার চালাবেন না। যৌথ ক্রমটি `npm run test:migration` দিয়ে যাচাই করা হয়।
3. `.env.example` কপি করে `.env.local` বানান। `NEXT_PUBLIC_SUPABASE_URL` ও `NEXT_PUBLIC_SUPABASE_ANON_KEY` Supabase project থেকে নিন। `SUPABASE_SERVICE_ROLE_KEY` কেবল স্থানীয় provision script-এর জন্য; এটি **Vercel-এ সেট করবেন না**, `NEXT_PUBLIC_` নাম দেবেন না এবং Git-এ রাখবেন না।
4. `demo-accounts.example.json` কপি করে `demo-accounts.local.json` বানান। নিজের নিয়ন্ত্রিত ডেমো ইমেইল ও প্রতিটি অ্যাকাউন্টের আলাদা, শক্ত পাসওয়ার্ড লিখুন। `example.test` ঠিকানাগুলো শুধু placeholder। এই স্থানীয় ফাইল Git-এ যাবে না।
5. `npm install`, তারপর `npm run demo:provision` চালান। স্ক্রিপ্ট প্রশাসনিক Auth API দিয়ে dummy account তৈরি/লিঙ্ক করে, ছয়টি ধারণামূলক দৃশ্য ও দুটি ছোট ভিডিও প্রাইভেট bucket-এ আপলোড করে এবং ১৮টি কাল্পনিক ঘটনা ও সংশ্লিষ্ট কাজ পুনরায় seed করে। আগে থেকে থাকা অ্যাকাউন্টের পাসওয়ার্ড স্ক্রিপ্ট পরিবর্তন করে না। Provision করলে নমুনা scenario workflow আবার শুরু হয়; মোবাইল নাগরিক ও জরিপের নথি অক্ষত থাকে।
6. `npm run dev` চালিয়ে `http://localhost:3000` খুলুন। যাচাই: `npm run typecheck`, `npm run test:migration` এবং `npm run build`।

ডেমোর জন্য executive, drainage head, drainage supervisor, পাঁচ বিভাগের field employee এবং ঐচ্ছিক drainage survey operator টেমপ্লেটে আছে। জরিপ অপারেটর এই ওয়েব প্রোটোটাইপে নিজ বিভাগের **পাঠযোগ্য** নথি দেখেন; জরিপ জমা দেওয়ার পাতা নেই। আগে থেকে তৈরি `demo-accounts.local.json` ফাইলে অপারেটর চাইলে আলাদা শক্ত পাসওয়ার্ডসহ নতুন এন্ট্রি যোগ করুন। কোনো পাসওয়ার্ড ওয়েবসাইটে দেখানো বা কোডে রাখা হয়নি।

## Vercel

এই Next.js রিপোজিটরি Vercel-এ যুক্ত করুন। শুধু `NEXT_PUBLIC_SUPABASE_URL` ও `NEXT_PUBLIC_SUPABASE_ANON_KEY` environment variable দিন। Supabase Auth redirect/site URL-এ deployment domain দিন। **Service role key ও account JSON Vercel-এ দেবেন না।** `next build` server runtime প্রয়োজন; static export করবেন না। ডেমো অ্যাকাউন্ট provision স্থানীয় প্রশাসনিক কম্পিউটার থেকে করা হয়।

## প্রদর্শনের পথ

**নতুন সমন্বিত অপারেশন:** কর্মকর্তার সাইন ইনের পর `/operations` খুলুন। চারটি seeded case-এ বর্জ্য, ড্রেন, ভবনের ফাঁক ও ছাদবাগান, ফুটপাত, sewer overflow ও ক্লিনিকের জরুরি পথ দেখা যায়। নমুনা map-এ সংযুক্ত স্থাপনার trace ও CCTV blind area, অনুমোদনসাপেক্ষ drone route, footage review, ব্যাখ্যাসহ priority, সরঞ্জাম না থাকলে আটকে যাওয়া কাজ, বিভাগ ও অংশীদারের acknowledgement/blocker, নাগরিক update-এর খসড়া, road crash/fire responder handoff এবং repeat-issue watch অনুশীলন করা যায়। এগুলো এই browser session-এর rehearsal; কোনো hardware, emergency unit বা database task-এ বার্তা পাঠায় না। একই JSON seed `src/lib/operations-seed.json` ও Flutter-এর `assets/operations-seed.json`-এ রাখা হয়েছে। বাস্তব shared assignment এখনও ঘটনা কেন্দ্র ও কাজের তালিকায় হয়। Engineering sequence, data contract ও pilot gate: [`docs/UNIFIED_CITY_OPERATIONS_ROADMAP.md`](docs/UNIFIED_CITY_OPERATIONS_ROADMAP.md)।

1. নির্বাহী অ্যাকাউন্ট → সারসংক্ষেপ, মানচিত্র ও ঘটনা দেখুন।
2. **রিয়েলটাইম অ্যানালাইসিস** খুলুন। চারটি প্রাইভেট নমুনা CCTV/ড্রোন দৃশ্য একসঙ্গে দেখা যায়; ভিডিও দুটি রেকর্ড করা লুপ, নেটওয়ার্ক লাইভ ফিড নয়। `mixed` দৃশ্য বেছে **দৃশ্যে চিহ্ন দিন** চাপুন এবং সমস্যার ওপর বক্স আঁকুন। খোলা ডেমো ঘটনা ও নির্দিষ্ট মাঠকর্মী বেছে কাজ পাঠান। কাজের নোটে চিহ্নের অবস্থান ও ভিডিও সময় থাকে; কর্মীর ঘটনা পাতায় চিহ্নটি দেখা যায়। ওয়েব বিজ্ঞপ্তি এবং Flutter কাজের পাতায় নতুন দায়িত্ব দেখুন। স্কোর ও শনাক্তকরণ **সিমুলেটেড**।
3. ঘটনা কেন্দ্রে পর্যবেক্ষণ যাচাই করে ঘটনা তৈরি করুন। একই ঘটনায় drainage ও waste বিভাগে আলাদা দায়িত্ব দিন।
4. মাঠকর্মীর অ্যাকাউন্টে সাইন ইন করে দায়িত্ব গ্রহণ, কাজ শুরু এবং বিবরণসহ পরের ডেমো দৃশ্য জমা দিন।
5. তত্ত্বাবধায়ক বা প্রধান ফল অনুমোদন বা পুনরায় কাজের জন্য পাঠান। নির্বাহী প্রতিবেদন ও সময়রেখায় পরিবর্তন দেখুন।
6. নির্বাহী অ্যাকাউন্টের “ডেমো আবার শুরু করুন” বোতাম দিয়ে শুধু নমুনা গল্পটি শুরুর অবস্থায় ফেরানো যায়; মোবাইল থেকে জমা দেওয়া নথি মুছে যায় না।

নিজের ছবি বা ভিডিও নির্বাচনের UI কেবল এই ডিভাইসে প্রিভিউ দেখায়; ফাইল আপলোড বা বিশ্লেষণ করে না। ক্যামেরা/স্ক্রিন শেয়ার শুধু ব্যবহারকারীর অনুমতিতে ব্রাউজারে চলে; এটি CCTV বা ড্রোনের সরাসরি সংযোগ নয়। দুটি ছোট ভিডিও দৃশ্যও সম্পূর্ণ কৃত্রিম; বাস্তব ভিডিও বিশ্লেষণ নেই। স্কোর, স্থানাঙ্ক ও ১৮টি ঘটনা কাল্পনিক। কোনো রোগ শনাক্তকরণ, বন্যার পূর্বাভাস, পৌর সংযোগ, ইমেইল, SMS বা push notification চালু নেই।

## নিরাপত্তা ও যাচাই

- Next proxy ও server data layer প্রতিটি অভ্যন্তরীণ পাতা যাচাই করে। Scenario workflow `perform_demo_action` এবং মোবাইল intake review `review_intake_observation` Postgres function-এ হয়; সরাসরি client write grant নেই। RLS একই তথ্যসীমা বজায় রাখে।
- Executive সব ডেমো তথ্য দেখেন; head নিজ বিভাগের; supervisor নিজের দলের নির্ধারিত ঘটনা ও কাজ; field employee নিজের কাজ ও সংশ্লিষ্ট ঘটনা দেখেন। নতুন পর্যবেক্ষণ যাচাই executive ও head করেন। প্রাইভেট মিডিয়া authenticated route এবং storage policy দিয়ে দেওয়া হয়।
- Incognito-তে `/dashboard`, `/incidents`, `/api/reports/export`, `/api/media/scenarios/drain.svg` পরীক্ষা করুন। কোনো অভ্যন্তরীণ তথ্য ফেরত আসা উচিত নয়। ভিন্ন role দিয়ে অন্য ঘটনার UUID বা task UUID পাঠিয়ে permission পরীক্ষা করুন।
- দুইটি browser/device-এ আলাদা account খুলে assignment ও status পরিবর্তন দেখুন। Invalid transition (যেমন গ্রহণ না করে কাজ শুরু) database প্রত্যাখ্যান করবে।
- প্রকৃত Supabase project/key ছাড়া build ও public landing যাচাই করা যায়; shared-state এবং RLS end-to-end পরীক্ষা করতে project setup প্রয়োজন।
- `npm run test:layout` চালাতে আগে `npm run dev` বা `npm run start` দিয়ে স্থানীয় সাইট চালু রাখুন। স্ক্রিপ্ট স্থানীয় Chrome দিয়ে ৩৯০ পিক্সেল mobile viewport ও sign-in অংশের ছবি যাচাই করে।
- `npm run test:official-layout` চালাতে স্থানীয় সাইট, Supabase ও ব্যক্তিগত ডেমো অ্যাকাউন্ট প্রস্তুত রাখুন। এটি নির্বাহী ১৩৬৬×৭৬৮ এবং মাঠকর্মী ৩৯০×৮৪৪ স্ক্রিনশট ও horizontal overflow পরীক্ষা করে; কোনো পাসওয়ার্ড প্রিন্ট করে না।
- `npm run test:operations-demo` একই প্রস্তুতি নিয়ে seeded planning loop-এ click-through, desktop/mobile layout এবং viewport overflow যাচাই করে। পুরোনো account password বদলে গেলে আগে স্থানীয় account JSON ও Supabase sign-in মিলিয়ে নিন।
- `npm run test:web-boundary` চালালে signed-out URL/API এবং নাগরিক A-এর ওয়েব কর্মকর্তা সাইন ইন বন্ধ আছে কি না যাচাই হয়।

দুই ক্লায়েন্টের পূর্ণ পরীক্ষা ও রেকর্ডিং পরিকল্পনা: [`INTEGRATION_TEST_AND_RECORDING_PLAN.md`](./INTEGRATION_TEST_AND_RECORDING_PLAN.md)। শুধু নমুনা scenario-এর অতিরিক্ত rehearsal: [`DEMO_TEST_PLAN.md`](./DEMO_TEST_PLAN.md)।
