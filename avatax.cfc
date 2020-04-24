component {
	// cfprocessingdirective( preserveCase=true );

	function init(
		required string apiUser
	,	required string apiPassword
	,	required string apiMode= "sandbox"
	,	required string apiVersion= "2"
	,	string appName= "CFML Client"
	) {
		this.apiUser= arguments.apiUser;
		this.apiPassword= arguments.apiPassword;
		this.apiMode= arguments.apiMode;
		this.apiVersion= arguments.apiVersion;
		this.apiUrl= ( arguments.apiMode == "live" ? "https://rest.avatax.com/api" : "https://sandbox-rest.avatax.com/api" ) & "/v#this.apiVersion#";
		this.appName= arguments.appName;
		this.httpTimeOut= 120;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "avatax: " & arguments.input );
			} else {
				request.log( "avatax: (complex type)" );
				request.log( arguments.input );
			}
			var info= ( isSimpleValue( arguments.input ) ? arguments.input : serializeJson( arguments.input ) );
			cftrace(
				var= "info"
			,	category= "avatax"
			,	type= "information"
			);
		}
		return;
	}

	function ping() {
		return this.apiRequest( api= "GET /utilities/ping" );
	}

	function listAccountUsers( string accountID ) {
		return this.apiRequest( api= "GET /accounts/#this.accountID#/users" );
	}

	function listUsers() {
		return this.apiRequest( api= "GET /users" );
	}

	function createUser() {
		return this.apiRequest( api= "POST /accounts/#this.accountID#/users" );
	}

	function listCompanies() {
		return this.apiRequest( api= "GET /companies" );
	}

	function listCustomers() {
		return this.apiRequest( api= "GET /companies/#this.companyID#/customers" );
	}
	
	function getCustomer( string code ) {
		return this.apiRequest( api= "GET /companies/#this.companyID#/customers/#arguments.code#" );
	}

	function listLocationsByCompany() {
		return this.apiRequest( api= "GET /companies/#this.companyID#/locations" );
	}

	function listTaxRules() {
		return this.apiRequest( api= "GET /companies/#this.companyID#/taxrules" );
	}

	function listTransactionsByCompany() {
		return this.apiRequest( api= "GET /companies/#this.companyCode#/transactions" );
	}
	
	function getTransaction( string id ) {
		return this.apiRequest( api= "GET /transactions/#arguments.id#" );
	}

	function createSalesOrder(
		string companyCode= this.companyCode
	) {
		arguments.type= "SalesOrder";
		arguments.date= now();
		return this.apiRequest( api= "POST /transactions/create?$include=SummaryOnly", argumentCollection= arguments );
	}

	function createTransaction(
		string type= "SalesOrder"
	,	string companyCode= this.companyCode
	,	date= now()
	) {
		return this.apiRequest( api= "POST /transactions/create", argumentCollection= arguments );
	}

	function resolveAddress(
		required string line1
	,	string line2
	,	string line3
	,	required string city
	,	required string region
	,	required string postalCode
	,	required string country
	,	string textCase= "Mixed" // Upper
	) {
		return this.apiRequest( api= "GET /addresses/resolve", argumentCollection= arguments );
	}

	function taxRatesByAddress(
		required string line1
	,	string line2
	,	string line3
	,	required string city
	,	required string region
	,	required string postalCode
	,	required string country
	) {
		return this.apiRequest( api= "GET /taxrates/byaddress", argumentCollection= arguments );
	}

	function taxRatesByPostalCode(
		required string country
	,	required string postalCode	
	) {
		return this.apiRequest( api= "GET /taxrates/bypostalcode", argumentCollection= arguments );
	}

	struct function apiRequest( required string api ) {
		var http= {};
		var dataKeys= 0;
		var item= "";
		var out= {
			success= false
		,	args= arguments
		,	error= ""
		,	status= ""
		,	json= ""
		,	statusCode= 0
		,	response= ""
		,	verb= listFirst( arguments.api, " " )
		,	requestUrl= this.apiUrl & listRest( arguments.api, " " )
		,	headers= {}
		};
		if( len( this.apiUser ) ) {
			out.headers[ "Authorization" ]= "Basic " & toBase64( '#this.apiUser#:#this.apiPassword#' );
		}
		structDelete( out.args, "api" );
		// structDelete( out.args, "auth" );
		if ( out.verb == "GET" ) {
			out.requestUrl &= this.structToQueryString( out.args, out.requestUrl, true );
		} else if ( !structIsEmpty( out.args ) ) {
			out.body= serializeJSON( out.args );
		}
		this.debugLog( "API: #uCase( out.verb )#: #out.requestUrl#" );
		out.headers[ "Accept" ]= "application/json";
		out.headers[ "Content-Type" ]= "application/json";
		out.headers[ "X-Avalara-Client" ]= "#this.appName#; CFAvaTax; 0.1";
		if ( request.debug && request.dump ) {
			this.debugLog( out );
		}
		cftimer( type= "debug", label= "avalara request: #out.requestUrl#" ) {
			cfhttp( result= "http", method= out.verb, url= out.requestUrl, charset= "UTF-8", throwOnError= false, timeOut= this.httpTimeOut ) {
				if ( structKeyExists( out, "body" ) ) {
					cfhttpparam( type= "body", value= out.body );
				}
				for ( item in out.headers ) {
					cfhttpparam( name= item, type= "header", value= out.headers[ item ] );
				}
			}
		}
		// this.debugLog( http );
		out.response= toString( http.fileContent );
		//this.debugLog( out.response );
		out.statusCode= http.responseHeader.Status_Code ?: 500;
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.success= false;
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		// parse response 
		if ( len( out.response ) && isJson( out.response ) ) {
			try {
				out.response= deserializeJSON( out.response );
			} catch (any cfcatch) {
				out.error= "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		} else {
			out.error= "Response not JSON: #out.response#";
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		this.debugLog( out.statusCode & " " & out.error );
		return out;
	}

	string function structToQueryString(required struct stInput, string sUrl= "", boolean bEncode= true) {
		var sOutput= "";
		var sItem= "";
		var sValue= "";
		var amp= ( find( "?", arguments.sUrl ) ? "&" : "?" );
		for ( sItem in stInput ) {
			sValue= stInput[ sItem ];
			if ( !isNull( sValue ) && len( sValue ) ) {
				if ( bEncode ) {
					sOutput &= amp & sItem & "=" & urlEncodedFormat( sValue );
				} else {
					sOutput &= amp & sItem & "=" & sValue;
				}
				amp= "&";
			}
		}
		return sOutput;
	}
	
}
