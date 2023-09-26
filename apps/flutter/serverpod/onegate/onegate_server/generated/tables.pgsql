--
-- Class DeliveryVisitors as table delivery_visitors
--

CREATE TABLE "delivery_visitors" (
  "id" serial,
  "visitor_id" integer NOT NULL,
  "delivery_person_name" text NOT NULL,
  "delivery_comapny" text NOT NULL
);

ALTER TABLE ONLY "delivery_visitors"
  ADD CONSTRAINT delivery_visitors_pkey PRIMARY KEY (id);


--
-- Class GuestVisitors as table guest_visitors
--

CREATE TABLE "guest_visitors" (
  "id" serial,
  "visitor_id" integer NOT NULL,
  "guest_name" text NOT NULL,
  "guest_coming_from" text NOT NULL,
  "guest_count" integer NOT NULL
);

ALTER TABLE ONLY "guest_visitors"
  ADD CONSTRAINT guest_visitors_pkey PRIMARY KEY (id);


--
-- Class MemberCategories as table member_categories
--

CREATE TABLE "member_categories" (
  "id" serial,
  "name" text NOT NULL,
  "status" text NOT NULL,
  "created_at" timestamp without time zone NOT NULL,
  "updated_at" timestamp without time zone NOT NULL
);

ALTER TABLE ONLY "member_categories"
  ADD CONSTRAINT member_categories_pkey PRIMARY KEY (id);


--
-- Class MemberStaff as table member_staff
--

CREATE TABLE "member_staff" (
  "id" serial,
  "name" text NOT NULL,
  "phone" text NOT NULL,
  "dob" timestamp without time zone NOT NULL,
  "gender" text NOT NULL,
  "member_category_id" integer NOT NULL,
  "member_sub_category_id" integer NOT NULL,
  "email" text NOT NULL,
  "address" text NOT NULL,
  "verification_type_id" integer NOT NULL,
  "verification_number" text NOT NULL,
  "profile_image_url" text NOT NULL,
  "status" text NOT NULL,
  "deleted_by" text NOT NULL,
  "created_at" timestamp without time zone NOT NULL,
  "created_by" text NOT NULL,
  "updated_at" timestamp without time zone NOT NULL,
  "updated_by" text NOT NULL
);

ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_pkey PRIMARY KEY (id);


--
-- Class MemberSubCategories as table member_sub_categories
--

CREATE TABLE "member_sub_categories" (
  "id" serial,
  "name" text NOT NULL,
  "member_category_id" integer NOT NULL,
  "status" text NOT NULL,
  "created_at" timestamp without time zone NOT NULL,
  "updated_at" timestamp without time zone NOT NULL
);

ALTER TABLE ONLY "member_sub_categories"
  ADD CONSTRAINT member_sub_categories_pkey PRIMARY KEY (id);


--
-- Class StaffBuildingUnits as table staff_building_units
--

CREATE TABLE "staff_building_units" (
  "id" serial,
  "staff_company_building_id" integer NOT NULL,
  "unit_id" integer NOT NULL
);

ALTER TABLE ONLY "staff_building_units"
  ADD CONSTRAINT staff_building_units_pkey PRIMARY KEY (id);


--
-- Class StaffCompanies as table staff_companies
--

CREATE TABLE "staff_companies" (
  "id" serial,
  "member_staff_id" integer NOT NULL,
  "company_id" integer NOT NULL
);

ALTER TABLE ONLY "staff_companies"
  ADD CONSTRAINT staff_companies_pkey PRIMARY KEY (id);


--
-- Class StaffCompanyBuilding as table staff_company_building
--

CREATE TABLE "staff_company_building" (
  "id" serial,
  "staff_comapany_id" integer NOT NULL,
  "building_id" integer NOT NULL
);

ALTER TABLE ONLY "staff_company_building"
  ADD CONSTRAINT staff_company_building_pkey PRIMARY KEY (id);


--
-- Class StaffVisitors as table staff_visitors
--

CREATE TABLE "staff_visitors" (
  "id" serial,
  "visitor_id" integer NOT NULL,
  "member_sub_category_id" text NOT NULL
);

ALTER TABLE ONLY "staff_visitors"
  ADD CONSTRAINT staff_visitors_pkey PRIMARY KEY (id);


--
-- Class TransportVisitors as table transport_visitors
--

CREATE TABLE "transport_visitors" (
  "id" serial,
  "visitor_id" integer NOT NULL,
  "driver_name" integer NOT NULL
);

ALTER TABLE ONLY "transport_visitors"
  ADD CONSTRAINT transport_visitors_pkey PRIMARY KEY (id);


--
-- Class VendorVisitors as table vendor_visitors
--

CREATE TABLE "vendor_visitors" (
  "id" serial,
  "visitor_id" integer NOT NULL,
  "vendor_name" text NOT NULL,
  "member_sub_category_id" text NOT NULL
);

ALTER TABLE ONLY "vendor_visitors"
  ADD CONSTRAINT vendor_visitors_pkey PRIMARY KEY (id);


--
-- Class VerificationTypes as table verification_types
--

CREATE TABLE "verification_types" (
  "id" serial,
  "name" text NOT NULL,
  "status" text NOT NULL,
  "created_at" timestamp without time zone NOT NULL,
  "updated_at" timestamp without time zone NOT NULL
);

ALTER TABLE ONLY "verification_types"
  ADD CONSTRAINT verification_types_pkey PRIMARY KEY (id);


--
-- Class VisitorBuildingUnits as table visitor_building_units
--

CREATE TABLE "visitor_building_units" (
  "id" serial,
  "visitor_company_building_id" integer NOT NULL,
  "unit_id" integer NOT NULL
);

ALTER TABLE ONLY "visitor_building_units"
  ADD CONSTRAINT visitor_building_units_pkey PRIMARY KEY (id);


--
-- Class VisitorCompanies as table visitor_companies
--

CREATE TABLE "visitor_companies" (
  "id" serial,
  "visitor_id" integer NOT NULL,
  "company_id" integer NOT NULL
);

ALTER TABLE ONLY "visitor_companies"
  ADD CONSTRAINT visitor_companies_pkey PRIMARY KEY (id);


--
-- Class VisitorCompanyBuildings as table visitor_company_buildings
--

CREATE TABLE "visitor_company_buildings" (
  "id" serial,
  "visitor_company_id" integer NOT NULL,
  "building_id" integer NOT NULL
);

ALTER TABLE ONLY "visitor_company_buildings"
  ADD CONSTRAINT visitor_company_buildings_pkey PRIMARY KEY (id);


--
-- Class Visitors as table visitors
--

CREATE TABLE "visitors" (
  "id" serial,
  "mobile" text NOT NULL,
  "member_category_id" integer NOT NULL,
  "visitor_img_url" text NOT NULL,
  "in_gate_id" integer NOT NULL,
  "in_time" timestamp without time zone NOT NULL,
  "out_gate_id" integer NOT NULL,
  "out_time" timestamp without time zone NOT NULL,
  "permission_status" text NOT NULL,
  "visitor_count" integer NOT NULL,
  "passcode" text NOT NULL,
  "created_at" timestamp without time zone NOT NULL,
  "created_by" text NOT NULL,
  "updated_at" timestamp without time zone NOT NULL,
  "updated_by" text NOT NULL
);

ALTER TABLE ONLY "visitors"
  ADD CONSTRAINT visitors_pkey PRIMARY KEY (id);


