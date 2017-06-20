<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html 
	PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" 
	"DTD/xhtml1-strict.dtd">
	
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
	<link rel="stylesheet" type="text/css" href="<shibmlp styleSheet/>" />
  <script type='text/javascript' src='//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js'></script>
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7" crossorigin="anonymous">

	<title>Login failed due to missing user attributes</title>
  <script>
    $(document).ready(function() {
        $("#textarea").val(
         $('#textarea').val().replace(/\ \*\ (\r\n|\n|\r)/ig,"")
        );
        var mailto = "<shibmlp Meta-Support-Contact/>";
        var target = "<shibmlp target />";
        var target = target.replace("&#58;", ":");
        mailto = mailto.split("&#58;").pop();
        $("#email").attr('href','mailto:' + mailto + '?subject=Attributes missing for ' + encodeURIComponent(target) + '&cc=<shibmlp supportContact/>' + '&body=' + encodeURIComponent(document.getElementById('textarea').value));
        
        $('#showdetails').click(function() {
          $('#details').slideToggle("fast");
        });
        $('#showdetails2').click(function() {
          $('#details').slideToggle("fast");
        });

        document.getElementById("support").innerHTML=mailto;
        document.getElementById("support2").innerHTML=mailto;
    });
  </script>
</head>

<body>
  <div id="msg"/>
    <div class="container">
      <!--PixelTracking-->
      <img title="track" src="/track.png?idp=<shibmlp entityID/>&miss=" alt="" width="1" height="1" />
      <div class="hero-unit">
        <h2>Login failed due to missing user attributes</h2>
          <p>
          You could unfortunately not login to to our service <shibmlp target />, because your home organization <shibmlpif Meta-displayName>(<shibmlp Meta-displayName />)</shibmlpif> did not provide all information about you that is needed by this service.
          </p>
          <a href="#" id="showdetails">Show details</a>
      	  <br/>
          <div id="details" style="display:none">
<hr>
           "The following user information in form of SAML attributes is needed by this service. Required but missing attribute values are marked in red."
          <div class="row">
            <div class="col-sm-5">
              <table class="table table-sm">
                <thead>
                  <tr><th colspan=2>Connection summary</th></tr>
                </thead>
                <tr>
                  <th>IdP</th>
                  <td><shibmlp Meta-displayName /></td>
                </tr>
                 <tr>
                   <td>entityId</td>
                   <td><shibmlp entityID/></td>
                </tr>
                <tr>
                  <th>SP</th>
                  <td><shibmlp target /></td>
                </tr>
                <tr>
                  <th>Time</th>
                  <td><shibmlp now/></td>
                </tr>
                <tr>
                  <th>Contact</th>
                  <td id="support"><shibmlp Meta-Support-Contact/></td>
                </tr>
              </table>
            </div>
            <div class="col-sm-7">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Attribute</th>
                    <th>Value</th>
                  </tr>
                </thead>
                <tbody>
<!--TableStart-->
<!--TableEnd-->
                </tbody>
              </table>
            </div>
          </div>
          Email template for your IdP Administrator
<textarea id="textarea" style="width:100%;height:100px;">
Dear <shibmlpif Meta-displayName><shibmlp Meta-displayName /></shibmlpif> IdP Administrator

I tried to log in to a service with the entityID "<shibmlp target />" today (<shibmlp now />). Unfortunately, the login failed because the <shibmlpif Meta-displayName><shibmlp Meta-displayName /></shibmlpif> Identity Provider did not release the requested user attributes to this service. To be able to access this service, I kindly ask you to ensure that our Identity Provider releases my user attributes to https://devsp.funet.fi/secure. Please find a summary of the login attempt below.

The attributes that were not released to the service are:

Connection summary:
 * IdP:      <shibmlp entityID/> (<shibmlp Meta-displayName />)
 * SP:       <shibmlp target />
 * Time:     <shibmlp now/>

Best Regards</textarea>
<hr>
</div>
          <p>
Please contact your home organisations helpdesk (here: <span id="support2"><shibmlp Meta-Support-Contact/></span>) and request attribute release for missing attributes. To do this, click on the button below. This will open your mail program with the needed technical information to resolve this issue. You can add additional information and review the email before sending it. Alternatively you can copy and paste the request from the  <a href="#" id="showdetails2">details</a> text box.
          </p>
          <a id="email" class="btn btn-primary btn-large" href="#">Report Problem to your Home Organisation's Helpdesk</a>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
