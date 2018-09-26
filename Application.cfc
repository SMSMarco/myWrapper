<!-----------------------------------------------------------------------
********************************************************************************
Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
Author     :	Luis Majano
Date        :	10/16/2007
Description :
	This is the Application.cfc for usage withing the ColdBox Framework.
	Make sure that it extends the coldbox object:
	coldbox.system.Coldbox
	So if you have refactored your framework, make sure it extends coldbox.
----------------------------------------------------------------------->
<cfcomponent output="false">
	<cfsetting enablecfoutputonly="yes">

	<cfset this.offlineStatus = false> <!---set this to true to activate scheduled maintenance message--->

	<!--- APPLICATION CFC PROPERTIES --->
	<cfset this.name = 'LA-API'>
	<cfset this.sessionManagement = true>
	<cfset this.sessionTimeout = createTimeSpan(0,0,30,0)>
	<cfset this.setClientCookies = true>

	<!--- COLDBOX STATIC PROPERTY, DO NOT CHANGE UNLESS THIS IS NOT THE ROOT OF YOUR COLDBOX APP --->
	<cfset COLDBOX_APP_ROOT_PATH = getDirectoryFromPath(getCurrentTemplatePath())>
	<!--- The web server mapping to this application. Used for remote purposes or static purposes --->
	<cfset COLDBOX_APP_MAPPING   = "">
	<!--- COLDBOX PROPERTIES --->
	<cfset COLDBOX_CONFIG_FILE 	 = "">
	<!--- COLDBOX APPLICATION KEY OVERRIDE --->
	<cfset COLDBOX_APP_KEY 		 = "">

	<!--- coldbox 4 in the web root directory: wwwroot/coldbox_4_3_0/--->
	<cfset this.mappings['/coldbox'] = replaceNoCase( COLDBOX_APP_ROOT_PATH, "myWrapper", "coldbox_4_3_0", "one")>

	<!--- map LA-API folder to web root to make it portable when installing with commandbox (Marco)--->
	<cfset this.mappings['/myWrapper'] = getDirectoryFromPath(getCurrentTemplatePath())>

	<!--- web root mapping --->
	<cfset this.mappings["/root"] = replace( getDirectoryFromPath(getCurrentTemplatePath()), "myWrapper\", "", "all" )>

	<!--- extenal modules mapping --->
	<cfset this.mappings["/modules_app"] = "C:\Users\ortiz\Documents\web\sandbox\versioning\modules_app">

	<!--- on Application Start --->
	<cffunction name="onApplicationStart" returnType="boolean" output="false">

		<cfif NOT this.offlineStatus>
			<cfscript>
				//Load ColdBox
				application.cbBootstrap = new coldbox.system.Bootstrap( COLDBOX_CONFIG_FILE, COLDBOX_APP_ROOT_PATH, COLDBOX_APP_KEY, COLDBOX_APP_MAPPING );
				application.cbBootstrap.loadColdbox();

				return true;
			</cfscript>
		</cfif>

	</cffunction>

	<!--- on Request Start --->
	<cffunction name="onRequestStart" returnType="boolean" output="true">

		<!--- ************************************************************* --->
		<cfargument name="targetPage" type="string" required="true" />
		<!--- ************************************************************* --->

		<!---return scheduled maintenance message--->
		<cfif this.offlineStatus>
			<cfset doOfflineStatus()>
		</cfif>

		<!---BEGIN LAPRO REINIT PROCESS--->

		<cfif
			structKeyExists( URL, "fwreinit" )
			OR NOT structKeyExists( application , "LAProReinit" )
		>
			<!---initialize the reinit component--->
			<cflock name="setLAProReinit" type="exclusive" timeout="5" throwontimeout="true">
				<cfset application.LAProReinit = new LAProReinit()>
			</cflock>
		</cfif>

		<cfif NOT structKeyExists( URL, "fwreinit" )>
			<!--- Check to see if reinit file has changed--->
			<cfset application.LAProReinit.checkReinitFile()>
		</cfif>

		<!---END LAPRO REINIT PROCESS--->


		<!--- BootStrap Reinit Check --->
		<cfif NOT structKeyExists(application,"cbBootstrap") or application.cbBootStrap.isfwReinit()>
			<cflock name="coldbox.bootstrap_#hash(getCurrentTemplatePath())#" type="exclusive" timeout="5" throwontimeout="true">
				<cfset structDelete(application,"cbBootStrap")>
				<cfset application.cbBootstrap = new coldbox.system.Bootstrap( COLDBOX_CONFIG_FILE, COLDBOX_APP_ROOT_PATH, COLDBOX_APP_KEY, COLDBOX_APP_MAPPING )>
			</cflock>
		</cfif>

		<!--- On Request Start via ColdBox --->
		<cfset application.cbBootstrap.onRequestStart(arguments.targetPage)>

		<cfreturn true>
	</cffunction>

	<!--- on Application End --->
	<cffunction name="onApplicationEnd" returnType="void"  output="false">
		<!--- ************************************************************* --->
		<cfargument name="appScope" type="struct" required="true">
		<!--- ************************************************************* --->

		<cfset arguments.appScope.cbBootstrap.onApplicationEnd(argumentCollection=arguments)>
	</cffunction>

	<!--- on Session Start --->
	<cffunction name="onSessionStart" returnType="void" output="false">
		<cfset application.cbBootstrap.onSessionStart()>
	</cffunction>

	<!--- on Session End --->
	<cffunction name="onSessionEnd" returnType="void" output="false">
		<!--- ************************************************************* --->
		<cfargument name="sessionScope" type="struct" required="true">
		<cfargument name="appScope" 	type="struct" required="false">
		<!--- ************************************************************* --->
		<cfset appScope.cbBootstrap.onSessionEnd(argumentCollection=arguments)>
	</cffunction>

	<!--- OnMissing Template --->
	<cffunction	name="onMissingTemplate" access="public" returntype="boolean" output="true" hint="I execute when a non-existing CFM page was requested.">
		<cfargument name="template"	type="string" required="true"	hint="I am the template that the user requested."/>
		<cfreturn application.cbBootstrap.onMissingTemplate(argumentCollection=arguments)>
	</cffunction>


	<!---offline status - returns a 503 response for scheduled maintenance--->
	<cffunction name="doOfflineStatus">

		<cfheader statuscode="503" statustext="Service Unavailable">
		<cfcontent type="application/json">
		<cfoutput>{"message":"The Lead Advantage Pro API is currently offline for scheduled maintenance. Please try your request later.","success":"0","result":"","statuscode":"503"}</cfoutput>
		<cfabort>

	</cffunction>

	<!--- fileLastModified --->
	<cffunction name="fileLastModified" access="private" returntype="string" output="false" hint="Get the last modified date of a file">

		<!--- ************************************************************* --->
		<cfargument name="filename" type="string" required="yes">
		<!--- ************************************************************* --->

		<cfscript>
		var objFile =  createObject("java","java.io.File").init(JavaCast("string",arguments.filename));
		// Calculate adjustments fot timezone and daylightsavindtime
		var Offset = ((GetTimeZoneInfo().utcHourOffset)+1)*-3600;
		// Date is returned as number of seconds since 1-1-1970
		return DateAdd('s', (Round(objFile.lastModified()/1000))+Offset, CreateDateTime(1970, 1, 1, 0, 0, 0));
		</cfscript>

	</cffunction>


</cfcomponent>