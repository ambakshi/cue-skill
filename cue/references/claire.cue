// Request schema for the Clairic extraction API.
//
// claire.schema.json is the Draft 2020-12 JSON Schema this file was derived from with
// `cue import`. This is the hand-maintained version: it keeps every constraint
// of the JSON Schema, but adds the things `cue import` cannot express —
// closed structs (unknown keys are rejected, as the API documents), named
// definitions, per-type key sets, and real types for min/max/step.
//
// Usage:
//
//	# check a request payload (the -d flag is required: #Request is a definition)
//	cue vet -c final.cue -d '#Request' request.json
//
//	# regenerate the JSON Schema
//	cue def final.cue -e '#Request' --out jsonschema
//
// Keep this file in sync with claire.schema.json: it is the readable, stricter twin of
// that schema, not a replacement for it.
@jsonschema(schema="https://json-schema.org/draft/2020-12/schema")

package clairic

import (
	"list"
	"struct"
)

// #FieldName is the pattern every field name and property name must match:
// a letter or underscore followed by up to 63 letters, digits, "_", "." or "-".
// Pattern constraints in CUE need a literal, so the pattern is spelled out
// again at each use site; this definition is the canonical statement of it.
#FieldName: =~"^[A-Za-z_][A-Za-z0-9_.\\-]{0,63}$"

// #ISODate is a calendar date written as YYYY-MM-DD.
#ISODate: =~"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

// #DataURL matches any embedded data: URL, the string form of an image.
#DataURL: =~"^[Dd][Aa][Tt][Aa]:"

// #PDFDataURL matches an embedded PDF data: URL, the string form of a document.
#PDFDataURL: =~"^[Dd][Aa][Tt][Aa]:[Aa][Pp][Pp][Ll][Ii][Cc][Aa][Tt][Ii][Oo][Nn]/[Pp][Dd][Ff];[Bb][Aa][Ss][Ee]64,"

// #Image is the object form of an embedded PNG, JPEG or WebP image. Remote
// URLs are not accepted: use the data: URL form instead.
#Image: {
	content_type!: string
	base64!:       string

	// Clockwise rotation to apply. Orientation is detected automatically when omitted.
	rotation?: 0 | 90 | 180 | 270
}

// #Document is the object form of an embedded PDF.
#Document: {
	content_type!: "application/pdf"
	base64!:       string
}

// #ObjectProperty is a property of an object field or of an object list item.
// Only the property's type is constrained; further keys are passed through.
#ObjectProperty: {
	type!: "text" | "number" | "boolean" | "enum"
	...
}

// #ObjectItems is the object form of a list field's item spec.
#ObjectItems: {
	type!:       "object"
	properties!: struct.MinFields(1) & {[=~"^[A-Za-z_][A-Za-z0-9_.\\-]{0,63}$"]: #ObjectProperty}
	...
}

// #ListItem is a list field's item spec: a scalar kind name or an object spec.
#ListItem: "text" | "number" | "date" | #ObjectItems

// #FieldCommon holds the keys every field spec may carry.
#FieldCommon: {
	// What the field should contain.
	instructions?: string

	// When false, text, number, boolean, enum and object answers cannot be null.
	nullable?: *true | bool
}

// #TextField extracts a span of the state.
#TextField: {
	#FieldCommon...
	type!: "text"

	// Allowed values. Optional for text fields.
	enum?: list.MinItems(1) & [..._]

	// text only.
	minLength?: int & >=0
	maxLength?: int & >=0

	// text only. Regular expression the answer must match.
	pattern?: string

	// Allows answers from prior knowledge that do not appear in the input.
	// Not combinable with source_only.
	knowledge?: bool
}

// #NumberField extracts a number.
#NumberField: {
	#FieldCommon...
	type!: "number"

	// number only. For durations, one of seconds, minutes, hours, days, weeks,
	// months, years (default seconds).
	unit?: string

	// number only.
	integer?: bool

	// number only. Values are rounded half-up.
	decimals?: int & >=0 & <=6

	// Allowed values. Optional for number fields.
	enum?: list.MinItems(1) & [..._]

	// number only.
	minimum?:          number
	maximum?:          number
	exclusiveMinimum?: number
	exclusiveMaximum?: number

	// Allows answers from prior knowledge that do not appear in the input.
	// Not combinable with source_only.
	knowledge?: bool

	// The answer must be printed in the input and is normalized from the printed
	// text. Not combinable with null_threshold or knowledge.
	source_only?: bool
}

// #ComputeField derives a number from the input.
#ComputeField: {
	#FieldCommon...
	type!: "compute"

	// compute requires true: a computed value is never null.
	nullable?: true

	unit?:     string
	integer?:  bool
	decimals?: int & >=0 & <=6

	// Probability of null above which the value is null (default 0.5).
	null_threshold?: >0 & <=1
}

// #DateField extracts a date.
#DateField: {
	#FieldCommon...
	type!: "date"

	// The answer must be printed in the input and is normalized from the printed
	// text. Not combinable with null_threshold.
	source_only?: bool

	null_threshold?: >0 & <=1
}

// #TimeField extracts a time.
#TimeField: {
	#FieldCommon...
	type!: "time"

	source_only?: bool

	null_threshold?: >0 & <=1
}

// #DatetimeField extracts a date and time.
#DatetimeField: {
	#FieldCommon...
	type!: "datetime"

	source_only?: bool

	null_threshold?: >0 & <=1
}

// #DurationField extracts a duration.
#DurationField: {
	#FieldCommon...
	type!: "duration"

	// One of seconds, minutes, hours, days, weeks, months, years (default seconds).
	unit?: string

	integer?:  bool
	decimals?: int & >=0 & <=6

	null_threshold?: >0 & <=1
}

// #BooleanField extracts a boolean.
#BooleanField: {
	#FieldCommon...
	type!: "boolean"
}

// #EnumField extracts one of a fixed set of values.
#EnumField: {
	#FieldCommon...
	type!: "enum"

	// Required for enum fields.
	enum!: list.MinItems(1) & [..._]
}

// #ObjectField extracts an object with named properties.
#ObjectField: {
	#FieldCommon...
	type!: "object"

	// Required for object fields.
	properties!: struct.MinFields(1) & {[=~"^[A-Za-z_][A-Za-z0-9_.\\-]{0,63}$"]: #ObjectProperty}
}

// #ListField extracts a list of scalars or objects.
#ListField: {
	#FieldCommon...
	type!: "list"

	// Required for list fields.
	items!: #ListItem

	// Maximum number of items to return.
	max_items?: int & >=0

	unit?:     string
	integer?:  bool
	decimals?: int & >=0 & <=6

	// Allowed values. Optional for list fields.
	enum?: list.MinItems(1) & [..._]

	// Not combinable with source_only.
	knowledge?: bool

	// Not combinable with knowledge.
	source_only?: bool
}

// #EstimateField extracts a number (or date) inside a range.
#EstimateField: {
	#FieldCommon...
	type!: "estimate"

	// Required for estimate fields: a number, or an ISO date for date estimates.
	min!: number | #ISODate
	max!: number | #ISODate

	// Estimate grid: a positive number (days for date estimates), or "month" / "year".
	step?: (number & >0) | "month" | "year"

	scale?: "linear" | "log"

	unit?: string
}

// #ForecastField projects a series forward from the input.
#ForecastField: {
	#FieldCommon...
	type!: "forecast"

	// Required for forecast fields: a number, or an ISO date for date estimates.
	min!: number | #ISODate
	max!: number | #ISODate

	// Forecast grid: a positive number (days for date estimates), or "month" / "year".
	step?: (number & >0) | "month" | "year"

	scale?: "linear" | "log"

	// Number of steps.
	horizon?: int & >=1 & <=64

	interval?: "step" | "minute" | "hour" | "day" | "week" | "month" | "quarter" | "year"

	unit?: string
}

// #FieldSpec is a single entry of the request's field map: exactly one typed
// variant applies, and each variant is closed to its own keys, so unknown keys
// for a field's type are rejected.
#FieldSpec: #TextField | #NumberField | #ComputeField | #DateField | #TimeField |
	#DatetimeField | #DurationField | #BooleanField | #EnumField | #ObjectField |
	#ListField | #EstimateField | #ForecastField

// #Request is a complete extraction request.
#Request: {
	// Required. The model selector.
	model!: *"clairic" | "@cf/cloudflare/clairic"

	// The text to read and predict from. Must be non-empty unless images or
	// documents are sent. Text answers are spans of this string.
	state?: *"" | string

	// Required. Map of field name to a typed field spec. At least one field; no
	// upper limit. Each prompt (state plus fields) must fit in 65,273 input
	// tokens; input is never truncated and oversized requests are rejected.
	fields!: struct.MinFields(1) & {[=~"^[A-Za-z_][A-Za-z0-9_.\\-]{0,63}$"]: #FieldSpec}

	// Optional embedded PNG, JPEG or WebP images placed before the state (max 4;
	// 4 MiB each, 8 MiB total decoded across images and documents; request body
	// max 16 MiB). Remote URLs are not accepted.
	images?: list.MaxItems(4) & [...(#DataURL | #Image)]

	// Optional embedded PDFs (4 MiB each). Rendered pages plus images must total
	// at most 4. Encrypted PDFs are rejected.
	documents?: list.MaxItems(4) & [...(#PDFDataURL | #Document)]

	// ISO date that anchors dates written without a year.
	reference_date?: #ISODate

	options?: {
		// Add 99 percentiles to estimates.
		include_quantiles?: *false | bool

		// Return the text that spans index into.
		return_state_text?: *false | bool
	}
}
