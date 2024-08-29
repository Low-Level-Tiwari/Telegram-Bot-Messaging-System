drop function creategroup;
drop function setresponse;
drop function sendmessage;
drop function tstart;
drop function ustart;
drop function addtogroup;
drop function validate_teacher_group;
drop function user_exists;
drop function addoneuser;
drop function sendfile;
drop function uploadfile;
drop function nustart;
drop function sendtouser;
drop function dmfile;
drop function fetchusernames;
drop function create_session;
drop function auth;
drop function fetchgroups;

create or replace function create_session_token() returns text as $$ 
declare 
	output text;
begin
	output := (select replace(gen_random_uuid()::text,'-',''));
	return output;
end;
$$ language plpgsql;

create or replace function setresponse(ts timestamp,code int,resd varchar(9600)) returns void as $$
begin 
	update comm set response=resd,rescode=code  where timest = ts;
end;
$$ language plpgsql;

create or replace function create_session(ts timestamp,data varchar(9600)) returns void as $$
declare
	output text;
begin
	output := substring(create_session_token(),1,6);
	update teachers set otp  =  output where teacher_name = data;
	
	execute setresponse(ts,200,(select TEACHERS_TG_ID from teachers where teacher_name=data)||'~'||output);
	EXCEPTION
		WHEN OTHERS then
			execute setresponse(ts,504,'Something Went Wrong');

end;
$$ language plpgsql;

create or replace function checksession(unm varchar(20),ot varchar(6)) returns boolean as $$ 
declare 
	output boolean;
	begin 
		output := false;
		select 1 into output from teachers where teacher_name = unm and otp = ot;
		if true = output then 
			output := true;
		else 
			output := false;
		end if;
		return output;
end;
$$ language plpgsql;

create or replace function auth(ts timestamp,data varchar(9600)) returns void as $$ 
declare 
	buff text[];
begin 
	buff = string_to_array(data,'~');
	if true = checksession(buff[1],buff[2]) then
		execute setresponse(ts,200,'Auth Successful');
	else 
		execute setresponse(ts,503,'Auth Failed');
	end if;
end;
$$ language plpgsql;

create or replace function fetchgroups(ts timestamp,data varchar(9600)) returns void as $$ 
declare 
	output text;
	tid bigint;
	it text;
	buff text[];
	begin
		buff := string_to_array(data,'~');
		if true = checksession(buff[1],buff[2]) then
			select TEACHERS_TG_ID into tid from teachers where teacher_name = buff[1];
			output = '';
			<<"loop">>
			for it in (select group_name from groups where TEACHERS_TG_ID=tid) loop
				output := output || it||',';
			end loop "loop";
			execute setresponse(ts,200,output);
		else 
			execute setresponse(ts,503,'Invalid Session');
		end if;
		EXCEPTION 
			WHEN OTHERS then
				execute setresponse(ts,503,'Something went wrong');
end;
$$ language plpgsql;
		
create or replace function fetchusernames(ts timestamp) returns void as $$ 
declare 
	output text;
	it text;
	begin
		output := '';
		<<"loop">>
		for it in (select teacher_name from teachers) loop
			output := output || it||',';
		end loop "loop";
		execute setresponse(ts,200,output);
	end;
$$ language plpgsql;	

create or replace function validate_teacher_group(gname varchar(50),tid BIGINT) returns boolean as $$ 
declare 
	output boolean;
begin
	output := false;
	output := (select 1 from groups where group_name = gname and TEACHERS_TG_ID=tid);
	if true = output then 
		output := true;
	else 
		output := false;
	end if;
	return output;
end;
$$ language plpgsql;

create or replace function sendmessage(ts timestamp, data varchar(9600)) returns void as $$
declare 
	buff text[];
	dat groups%rowtype;
	uuid varchar(33);
	tid bigint;
begin 
	buff := string_to_array(data,'~');
	if true = checksession(buff[1],buff[2]) then 
		select TEACHERS_TG_ID into tid from teachers where teacher_name = buff[1];
		select * into dat from groups where group_name=buff[3] and TEACHERS_TG_ID=tid;	
		uuid := create_session_token();
		insert into messages values(uuid,buff[4],dat.TEACHERS_TG_ID,dat.group_name);
		execute setresponse(ts,200,'Messages Listed will be sent shortly');
	else 
		execute setresponse(ts,503,'Invalid Session');
	end if;		
	EXCEPTION
		WHEN NO_DATA_FOUND
			then
			execute setresponse(ts,'Not a valid group configuration');
	  	WHEN OTHERS
	  		then
	  		execute setresponse(ts,'Something went wrong');
end;
$$ language plpgsql;


create or replace function populate_send_job() returns trigger as $$ 
begin 
	insert into sendjob(status,type,USERS_TG_ID,uuid) (select false,1,b.USERS_TG_ID,NEW.uuid from belongs b where b.group_name = NEW.group_name);
	return NEW;
end;
$$ language plpgsql;

create or replace function route() returns trigger as $$
begin 
	if 'createsession' = NEW.command then
		execute create_session(NEW.timest,NEW.data);
	elseif 'auth' = NEW.command then 
		execute auth(NEW.timest,NEW.data);
	elseif 'getgroups' = NEW.command then
		execute fetchgroups(NEW.timest,NEW.data);
	elseif 'sendtext' = NEW.command then
		execute sendmessage(NEW.timest,NEW.data);
	elseif 'sendfile' = NEW.command then
		execute sendfile(NEW.timest,NEW.data);
	elseif 'getunames' = NEW.command then
		execute fetchusernames(NEW.timest);
	else 
		execute setresponse(NEW.timest,503,'Bad Request');
	end if;
	return new;
end;
$$ language plpgsql;
------------------------------------------
create or replace function sendtouser(uuid bigint,message varchar(60)) returns void as $$ 
begin 
	insert into sendjob values(false,3,uuid,message);
end;
$$ language plpgsql;



create or replace function user_exists(rollno varchar(10)) returns boolean as $$ 
declare
	output boolean;
begin 
	output := false;
	output := (select 1 from users where rollnumber = rollno);
	if true = output then
		output := true;
	else 
		output := false;
	end if;
	return output;
end;
$$ language plpgsql;



create or replace function addtogroup(rollno varchar(10),gname varchar(50),tid BIGINT) returns boolean as $$
declare 
	output boolean;
begin 
	output := true;
	if true = validate_teacher_group(gname,tid) and true = user_exists(rollno) then
		insert into belongs values(gname,(select USERS_TG_ID from users where rollnumber=rollno));
	else
		output := false;
	end if;
	return output;
end;
$$ language plpgsql;


create or replace function creategroup(ts timestamp,gname varchar(50),tid bigint) returns void as $$
declare 
	flg boolean;
begin 
	flg := false;
	insert into groups values(gname,tid) returning 1 into flg;
	if true = flg then 	
		execute setresponse(ts,'Group created successfully');
	else 
		execute setresponse(ts,'Group Cannot be created');
	end if;
end;
$$ language plpgsql;


create or replace function tstart(ts timestamp,data varchar(9600)) returns void as $$
declare 
	buff text[];
	flg boolean;
	tid BIGINT;
begin 
	buff := string_to_array(data,'~');
	tid = CAST(buff[1] as BIGINT);
	flg := (select 1 from teachers where TEACHERS_TG_ID = tid);
	if true = flg then
		execute setresponse(ts,'Already Exists');
	else
		insert into teachers values(tid,buff[2]);
		execute setresponse(ts,'Successfully Registered');
	end if;
	
	update jobs set JOBS_TG_ID=tid where timest=ts; 
end;
$$ language plpgsql;


create or replace function nustart(ts timestamp,data varchar(9600)) returns void as $$
declare 
	buff text[];
	flg boolean;
	uuid BIGINT;
begin 
	buff := string_to_array(data,'~');
	--uuid = CAST(buff[1] as BIGINT);
	select  into flg,uuid 1,u.USERS_TG_ID from users u where u.Student_Name = buff[2] and u.rollnumber = buff[3];
	if true = flg then
		if uuid is null then 
			uuid := CAST(buff[1] as BIGINT);	
			update users set USERS_TG_ID=uuid where rollnumber = buff[3];
			execute sendtouser(uuid,'Successfully Registered');
		else
			execute sendtouser(uuid,'Already Exists');
		end if;
	else
		execute sendtouser(uuid,'Not Registered');
	end if;
end;
$$ language plpgsql;

create or replace function ustart(ts timestamp,data varchar(9600)) returns void as $$
declare 
	buff text[];
	flg boolean;
	uuid BIGINT;
begin 
	buff := string_to_array(data,'~');
	uuid = CAST(buff[1] as BIGINT);
	flg := (select 1 from users where USERS_TG_ID = uuid);
	if true = flg then
		execute setresponse(ts,'Already Exists');
	else
		insert into users values(uuid,buff[2],buff[3]);
		update jobs set JOBS_TG_ID=uuid where timest=ts; 
		execute setresponse(ts,'Successfully Registered');
	end if;
end;
$$ language plpgsql;

create or replace function addoneuser(ts timestamp, data varchar(9600),tid BIGINT) returns void as $$ 
declare 
	buff text[];
begin	
	buff := string_to_array(data,'~');
	if true = addtogroup(buff[1],buff[2],buff[3]) then 
	execute	setresponse(ts,'Added Successfully');
	else 
	execute	setresponse(ts,'Something Went Wrong');
	end if;		
end;
$$ language plpgsql;

create or replace function uploadfile(ts timestamp,data varchar(9600),tid bigint) returns void as $$ 
declare 
	buff text[];
begin
	buff := string_to_array(data,'~');
	insert into files values(buff[1],tid,buff[2]);
	execute setresponse(ts,'File Uploaded');
end;
$$ language plpgsql;

create or replace function sendfile(ts timestamp,data varchar(96000),tid BIGINT) returns void as $$
declare 
	buff text[];
	dat groups%rowtype;
	fd varchar(40);
begin 
	buff := string_to_array(data,'~');
	select fid into fd from files where fname = buff[2] and TEACHERS_TG_ID = tid;
	select * into dat from groups where group_name=buff[1] and TEACHERS_TG_ID=tid;	
	insert into sendjob(status,type,USERS_TG_ID,uuid) (select false,2,b.USERS_TG_ID,fd from belongs b where b.group_name = dat.group_name);
	execute setresponse(ts,'File will be sent shortly');
	EXCEPTION
		WHEN NO_DATA_FOUND
			then
			execute setresponse(ts,'Not a valid group configuration');
	  	WHEN OTHERS
	  		then
	  		execute setresponse(ts,'Something went wrong');
end;
$$ language plpgsql;

create function dmfile(ts timestamp,data varchar(9600),tid bigint) returns void as $$
declare 
	buff text[];
	fd varchar(40);
begin 
	buff := string_to_array(data,'~');
	select fid into fd from files where fname = buff[2] and TEACHERS_TG_ID = tid;
	insert into sendjob(status,type,USERS_TG_ID,uuid) values(false,2,(select USERS_TG_ID from users where rollnumber=buff[1])); 
	execute setresponse(ts,'File will be sent shortly');
	EXCEPTION
		WHEN NO_DATA_FOUND
			then
			execute setresponse(ts,'Not a valid group configuration');
	  	WHEN OTHERS
	  		then
	  		execute setresponse(ts,'Something went wrong');
end;
$$ language plpgsql;



create or replace trigger commander after insert on comm for each row execute function route();
create or replace trigger adder after insert on messages for each row execute function populate_send_job();
