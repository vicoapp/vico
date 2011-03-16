<%= expression to be printet %>

<%--
Block Comment
--%>

<%
// some scriptlet code
String name = request.getParameter("name");
if (name != null) {
 %>
 <h1><%= name %></h1>
 <%
} else {
 %>
 <h1 style="color:red">Error!</h1>
<u></u>
 <%
}
%>


<h1 id=""></h1>

<%!
String test = "hej med dig";
int i = 10;
%>

<%!
public class Test {
 private String testerString;

 public Test(String test){
   testerString = test;
 }

 public void getTest() {
   return this.testerString;
 }

}
%>

<%@ page import="java.util.*, java.lang.*" %>
<%@ page buffer="5kb" autoFlush="false" %>
<%@ page errorPage="error.jsp" %>
<%@ include file="relativeURL" %>
<%@ taglib uri="URIToTagLibrary" prefix="somePrefix" %>

<jsp:declaration>
String test = "blah";
</jsp:declaration>
<jsp:scriptlet>
if (test.equals("blah")) {
</jsp:scriptlet>
<jsp:expression>
"expression to be printet: " + test
</jsp:expression>
<jsp:scriptlet>
}
</jsp:scriptlet>

<%@ page language="java" %>
<%@ page contentType="text/html;charset=ISO-8859-1" %>
<%@ page import="java.util.*"%>
<%@ page import="java.lang.*"%>

<%@ taglib uri="/WEB-INF/escenic-util.tld" prefix="util" %>
<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean" %>
<%@ taglib uri="/WEB-INF/jppol-mail.tld" prefix="mail" %>

<bean:define id="script_bean_var_1" name="bean_var_1" type="String" />
<bean:define id="script_bean_var_2" name="bean_var_2" type="HashMap" />
<bean:define id="templateContext" name="templateContext" type="String" />

<%!
String exampleString = "blah: ";
%>

<%-- This comment is ok --%>

<mail:send>
    <mail:subject></mail:subject>
    <mail:to></mail:to>
    <mail:from></mail:from>
    <mail:body></mail:body>
</mail:send>

<%
String codeName = request.getAttribute("attribute_1");
if (codeName.equals("test_1"))) {
	// HERE: this is not source.java scope for some reason
}
if (request.getAttribute("configErrorString") != null) {
	configErrorString = (String) request.getAttribute("configErrorString");
}
if (request.getAttribute("foundConfigError") != null) {
	Boolean blnObj = (Boolean) request.getAttribute("foundConfigError");
	foundConfigError = blnObj.booleanValue();
}

if (!foundConfigError && request.getParameter("mail_send") != null) { 
  
  response.setContentType("text/javascript");
  
  String senderName  = request.getParameter("mail_sender_name");
  String senderEmail = request.getParameter("mail_sender_email");
  String senderText  = request.getParameter("mail_sender_text");
  
  JSONObject responseObj = new JSONObject();
  String errorStr = "";
  
  if (!configParametersMap.get("require_name").equals("false")  && (senderName == null  || senderName.equals("")  || senderName.equals("Dit navn")))   errorStr += configParametersMap.get("error_name") + "\n";
  if (!configParametersMap.get("require_email").equals("false") && (senderEmail == null || senderEmail.equals("") || senderEmail.equals("Din email"))) errorStr += configParametersMap.get("error_email") + "\n";
  if (senderText  == null || senderText.equals("")  || senderText.equals("Din besked")) errorStr += configParametersMap.get("error_message");

  if (errorStr.equals("")) { 
    %>
    <mail:send appid="14">
      <mail:to><%= configParametersMap.get("to") %></mail:to>
      <mail:from><%= configParametersMap.get("from") %></mail:from>
      <mail:subject><%= configParametersMap.get("subject") %></mail:subject>
      <mail:body><%= "Afsenders navn:  " + senderName + "\n\nAfsender email: " + senderEmail + "\n\nIndhold:\n\n" + senderText %></mail:body>
    </mail:send>
    <%
    responseObj.put("status", true);
  } else {
    responseObj.put("status", false);
    responseObj.put("error", errorStr);
  }
  
  out.print(responseObj);
  
} else if (!foundConfigError) { %>
  <script type="text/javascript" charset="utf-8">
    $(document).ready(function(){
      var old_text_color = $("#form100119 > txtarea1").css("color");
      
      $("#mail_sender_email").focus(function(){if($(this).val()=="Din email"){$(this).val("");$(this).css("color","black");}});
      $("#mail_sender_text").focus(function(){if($(this).val()=="Din besked"){$(this).val("");$(this).css("color","black");}});
      $("#mail_sender_name").focus(function(){if($(this).val()=="Dit navn"){$(this).val("");$(this).css("color","black");}});
      
      $("#mail_sender_email").blur(function(){if($(this).val()==""){$(this).css("color","#999");$(this).val("Din email");}});
      $("#mail_sender_text").blur(function(){if($(this).val()==""){$(this).css("color","#999");$(this).val("Din besked");}});
      $("#mail_sender_name").blur(function(){if($(this).val()==""){$(this).css("color","#999");$(this).val("Dit navn");}});
      
      $("#mail_sender_email").blur();
      $("#mail_sender_text").blur();
      $("#mail_sender_name").blur();
      	    
        $("#form100119").submit(function(){
            $.ajax({
                type: "POST",
                url: "<util:valueof param="article.url" />", 
                data: {
                    mail_sender_email: $("#mail_sender_email").val(),
                    mail_sender_text: $("#mail_sender_text").val(),
                    mail_sender_name: $("#mail_sender_name").val(),
                    mail_send: "true"
                },
                contentType: "application/x-www-form-urlencoded;charset=UTF-8",
                success: function(data){
                    if (data.status) {
                        $("#mail_sender_text, #mail_sender_email, #mail_sender_name, #mail_sender_submit").attr("disabled","disabled");
                        $("#mail_sender_text, #mail_sender_email, #mail_sender_name").val("");
                        $("#mail_sender_label").text("<%= configParametersMap.get("mail_sendt") %>");
                    } else {
                        alert(data.error);
                    }
                },
                dataType: "json"
                
            });
            return false;
        }); // submit func end
	  });
	</script>
	<%-- comment not working --%>
	<div class="boxid_105 <%= configParametersMap.get("color") # HERE: this conflicting with the ruby syntax built into the html grammar  %>">
		<div class="eb_round3"><b></b><span></span></div>
		<div class="eb_mid3">
			<ul class="eb_listtop clearfix">
				<li class="eb_fl"><%= configParametersMap.get("title") %> HERE : The preceding does never enter the source.java scope.
				    
				  </li>
				
			</ul>
			<form id="form100119" name="form100119" method="post" action="javascript:void(0)" accept-charset="iso-8859-1">
				<div class="txtarealarge">
					<label for="txtarea1" id="mail_sender_label"><%= configParametersMap.get("description") %></label>
					<textarea name="txtarea1" tabindex="1" id="mail_sender_text" cols="80" rows="10"></textarea>
					<a class="eb_smalllink" href="#">Vi forbehoilder os ret til at redigere og<br>offentilgg&oslash;re dit sp&oslash;rgsm&aring;l</a>
					<input name="mail_sender_name" tabindex="2" id="mail_sender_name" type="text" class="inp185" value="" /><input name="mail_sender_email" tabindex="3" id="mail_sender_email" type="text" class="inp185" value="" />
					<input class="sendbutton" id="mail_sender_submit" tabindex="4" type="submit" value="Send" />
				</div>
			</form>
		</div>
	</div>
	
<% } else { %>
		
	WHAT:::<%=configErrorString %>

<% } %>
<% if (false) { %>

<% String test = hello; // HERE: i can comment out end signs %>
%>


<%-- HERE: This should be captured as a comment --%>
<mail:send appid="14">
	<mail:to><%= configParametersMap.get("to") %></mail:to>
	<mail:from><%= configParametersMap.get("from") %></mail:from>
	<mail:subject><%= configParametersMap.get("subject") %></mail:subject>
	<mail:body>Dette er en test</mail:body>
</mail:send>
<% } %>