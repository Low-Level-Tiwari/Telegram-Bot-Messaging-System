drop table files cascade;
drop table sendjob cascade;
drop table messages cascade;
drop table belongs cascade;
drop table comm cascade;
drop table groups cascade;
drop table teachers cascade;
drop table users cascade;

create table teachers(
	TEACHERS_TG_ID bigint primary key,
	Teacher_Name varchar(50),
	otp varchar(6)
);

create table comm(
	command varchar(20),
	data varchar(9600),
	timest timestamp,
	response varchar(500),
	rescode int
);


create table users(
	USERS_TG_ID bigint primary key,
	rollnumber varchar(10) unique not null,
	Student_Name varchar(60)
);

create table groups(
	group_name varchar(50) not null,
	TEACHERS_TG_ID bigint not null references teachers(TEACHERS_TG_ID) on delete cascade,
	primary key(group_name,TEACHERS_TG_ID)
);

create table belongs(
	group_name varchar(50) not null,
	TEACHERS_TG_ID bigint not null,
	USERS_TG_ID bigint not null references users(USERS_TG_ID) on delete cascade,
	foreign key(group_name,TEACHERS_TG_ID) references groups(group_name,TEACHERS_TG_ID),
	primary key(group_name,TEACHERS_TG_ID,USERS_TG_ID)
);	

create table messages(
	uuid varchar(33) primary key,
	content varchar(600),
	TEACHERS_TG_ID bigint ,
	group_name varchar(50),
	foreign key(group_name,TEACHERS_TG_ID) references groups(group_name,TEACHERS_TG_ID)	
);
create table sendjob(
	status boolean,
	type int,
	USERS_TG_ID  bigint not null references users(USERS_TG_ID),
	uuid varchar(33) references messages(uuid)
);
create table files(
	fid varchar(40),
	TEACHERS_TG_ID bigint not null references teachers(TEACHERS_TG_ID),
	fname varchar(50)
);
