#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<libpq-fe.h>


char timest[100];
char uuid[35];

// Generate Current timestamp
void setTimestamp(PGconn *connector)
{
	PGresult *res;
	res = PQexec(connector,"select current_timestamp;");
	sprintf(timest,"%s",PQgetvalue(res,0,0));
}

// Remove the Command from comm table
void cleanup(PGconn *connector){
	char query[100];
	sprintf(query,"delete from comm where timest='%s' where command!='createsession'",timest);
	PQexec(connector,query);
}


// Generate uuid 
void setuuid(PGconn *connector)
{
	PGresult *res;
	res = PQexec(connector,"select create_session_token();");
	sprintf(uuid,"%s",PQgetvalue(res,0,0));
}


// Generate response for browser
void setresponse(int code,char *error){
	printf("Status: %d OK\r",code);
	printf("Content-Type: text/html\r");
	printf("\r");
	printf("%s\r",error);
}

// Check MD5 hash of file 
int checkmd5(PGconn *connector){

	int i=0;
	char cmd[175];
	char hash[33],hash_gen[33];
	int flg = 1;
	while(i<32)
	hash[i++]=getchar();
	hash[i]='\0';	
	sprintf(cmd,"md5 -q  %s  >%s.k",uuid,uuid);
	system(cmd);
	fgets(hash_gen,33,fopen(strcat(uuid,".k"),"r"));
	printf("-%s-%s-\n",hash,hash_gen);
	if(0!=strcmp(hash,hash_gen)){	
		setresponse(503,"File Uploaded is ambiguous");
		flg = 0;
	}
	sprintf(cmd,"rm %s",uuid);
	uuid[32] = '\0';
	system(cmd);
	return flg;
}


int main()
{
	char *len = getenv("CONTENT_LENGTH");
	int flg = 1;
	if(len!=NULL)
	{
		long length = atoi(len);
		int i=-1,j=0;

		// Extract Command and Data from request
		char command[20], data[400];
		do{
			i++;
			command[i] = getchar();
		}
		while(i<length && i<20 && command[i]!='|');
		command[i++] = '\0';
	
		do
		{data[j++] = getchar();i++;}
		while(i<length && j<400 && data[j-1]!='|'); 
		data[j-1] = '\0';
		
		
		// Establish Connection with Database
		const char *info;
		PGconn *connector;
		PGresult *res;
		int n;
		info = "dbname=bot";
		char query[600];
		connector = PQconnectdb(info);
		if(PQstatus(connector)!=CONNECTION_OK){
			setresponse(503,"Internal Connection Error");
		}
		else{
			// If command is sendfile, check MD5 hash
			if(strcmp(command,"sendfile")==0)
			{
				char c;
				setuuid(connector);
				FILE *fs = fopen(uuid,"w+");
				while((c=getchar())!='~')	
					fputc(c,fs);
				fclose(fs);
				flg = checkmd5(connector);
			}	
			if(1 == flg)
			{
				setTimestamp(connector);
				sprintf(query,"insert into comm values('%s','%s','%s');",command,data,timest);
				res = PQexec(connector,query);
				if(PQresultStatus(res) != PGRES_COMMAND_OK){
					setresponse(503,"Internal Result Error");
				}else{
				sprintf(query,"select rescode,response from comm where timest='%s';",timest); 
				res = PQexec(connector,query);
				if(PQresultStatus(res) != PGRES_TUPLES_OK){
					setresponse(503,"Internal Server Error");	
				}
				else
				{
					if(strcmp(command,"sendfile")==0)
					{
						if(200==atoi(PQgetvalue(res,0,0))){
							char cmd[175];
							sprintf(cmd,"mv %s data/%s",uuid,PQgetvalue(res,0,1));
							system(cmd); 
							setresponse(200,"File Uploaded Successfully");	
						}else{
							setresponse(503,PQgetvalue(res,0,1));	
						}	
					}
					else{
						setresponse(200,PQgetvalue(res,0,1));	
					}	
				}
				cleanup(connector);
				}
			}	
		}
	}
}
