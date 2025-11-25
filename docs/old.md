There is one point that has not been considered so far regarding what the SDK does:
When the robot’s configuration is sent from the server to the robot, first of all:
1.  In heartbeats, the entire configuration is not always sent. It is only sent when some parameters of the configuration change.
2.  This configuration is sent as JSON from the server to the robot in full. These configurations are actually the parameters that the developer has defined for their robot. Therefore, there must be a system that receives an 
object (a class or JSON) from the developer at the start of the robot. This object essentially represents the configuration parameters that the developer needs for the robot. In response to the start package, it must check whether 
all the fields in that object exist in the full configuration sent by the server in response to the start package or not. If not complete, it should throw an error.
3.  In each heartbeat, some of these configuration parameters may change. The SDK must have a mechanism that first checks whether the parameter sent by the server (that has changed) is valid or not. (To perform this check, the 
object the developer gives to the SDK at the beginning must also contain, for each parameter definition, a function to check its validity.)
o   If invalid, according to the protocol, in the next heartbeat package sent to the server, the reason for rejecting each parameter must be added.
o   If valid, the SDK memory must be updated with the new parameter, and then the robot (here, the robot means the code written by the developer) must be notified by a mechanism that certain parameters have been updated. The robot 
must then fetch the new parameters and update itself.
The same process applies to the session symbols part. If a request is sent from the server to the SDK to change active_to_trade, this request must also be handled like the configuration part, updating and notifying the robot.
If the SDK sends a heartbeat and receives a “token expired” response, it must send a refresh request and get a new token. Now, the data that was previously sent in the heartbeat (and got rejected) never reached the server. 
Therefore, the robot must have a memory that keeps this data until confirmation is received from the server, ensuring that the data the SDK sent is stored on the server.
In fact, we have three interfaces here:
•   Server – SDK – Robot
•   The server talks to the SDK.
•   The SDK talks to the robot.
Refactor the call files accordingly. Consider best practices.
In each heartbeat, another parameter is also added from the server when sending to the robot: the interval for sending heartbeats. In this parameter, the robot is told how long the interval between its heartbeats should be. To 
prevent manipulation of this parameter in the robot, a maximum value of 5 minutes will be hardcoded. If a parameter greater than 5 minutes is sent to the robot, the robot must assume the maximum (5 minutes).
In all files, add a section called SDK Process for Robot. Do not write code in it at all; just explain what the SDK must do for the robot in each of the scenarios.
Keep in mind that later we want to write an SDK for the robot that includes an MQL5 library, giving the developer the ability to use its functions so they can easily connect their robot to our system. That is our ultimate goal.
Note that the JWT payload will no longer be signed by the robot.
The robot just sends the JWT it has received to the server.
If you had included a signing or token-modification process by the robot, remove it.
The server’s job is to give the robot a JWT token with an unencrypted payload, so the robot knows exactly when the token will expire. If it has expired, the robot should not send a heartbeat request but instead send a refresh 
request.
Our goal with these endpoints is to make it easy to design an SDK for them.
Eventually, this SDK will be given to developers to use in their robots, so the robots can easily connect to our system.
1.  We no longer want to encrypt the payload of the JWT token. No encryption.
1.1. To validate a request, the following steps are checked:
o   First, check whether the JWT token’s signature is valid.
o   Then check the JWT token’s expiry time. If not valid, reject it.
o   If valid, check the cache to see whether there is an api_key for the given JWT. In fact, in our cache, we keep tokens along with their JWTs.
o   If not found, reject.
o   If found, check the api_key’s expiry date in the cache to see whether it has passed or not. If expired, reject.
So, in the cache we must keep not only the api_key but also its expiry date.
2.  Since we no longer encrypt the JWT payload, we do not need KMS in this part, so we remove KMS. To keep secrets in Secret Manager, we create a secret for JWT, which must have its own dedicated rotation. This rotation happens 
automatically.
3.  Since the payload is not encrypted, the robot knows exactly—before sending a heartbeat request—whether the token has expired or not. If expired, the robot will not send a heartbeat request; instead, it will send a refresh 
request.
4.  The robot must take care that sometimes the heartbeat request it sends may not reach the server (due to token expiration). In that case, important responses included in that heartbeat package never reach the server. Therefore, 
the robot must keep those responses so it can correctly resend them in the next package until they reach the server.
5.  If the server responds with invalid for a refresh or start request, the robot must not try again under the same conditions, because the server will not accept it. Instead, the rejection reason must be clear so that the robot 
knows exactly what went wrong (e.g., the api_key has reached the maximum allowed sessions, and the user must go into their panel and deactivate one session before a new session can start). Therefore, the reason for each rejection 
is important and must be specified.