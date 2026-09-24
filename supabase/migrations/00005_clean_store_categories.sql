-- 상가정보 자동 분류 정리
--  - 유흥·단란주점 등 성인 업소 제외
--  - '사진촬영업'은 셀프사진관 이름일 때만 놀거리로 유지 (웨딩·프로필 스튜디오 제외)
--  - 이름만 '갤러리'인 수선집·가구점 등 제외
--  - 음식점이 '공방 체험'·'카페'로 잘못 들어간 경우 제외
UPDATE public.places
   SET is_active = FALSE
 WHERE source = 'SEMAS'
   AND (
        coalesce(description, '') ~ '(유흥|단란|무도)'
     OR name ~ '(유흥|단란|나이트|카바레|룸살롱)'
     OR (category = 'ACTIVITY' AND subcategory = '셀프사진'
         AND name !~* '(셀프|포토|인생네컷|네컷|부스|필름|photo)')
     OR (category = 'EXHIBITION' AND coalesce(description, '') !~ '(예술품|전시|미술|박물)')
     OR (category = 'ACTIVITY' AND subcategory = '공방 체험'
         AND coalesce(description, '') ~ '(회/초밥|마라탕|훠궈|카페|주점|한식|한정식|중국|치킨|피자|분식|백반|구이|찜|경양식|면 요리|국수|빵)')
     OR (category = 'CAFE' AND coalesce(description, '') ~ '(주점|유흥|치킨|피자|김밥|백반|곱창|회/초밥|국수)')
   );
